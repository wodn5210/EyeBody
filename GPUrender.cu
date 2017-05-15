#include "GPUrender.cuh"
//프로젝트 20, 코드파일 12


//gpu 상수메모리
__constant__ int gResolution;
__constant__ int gVolumeSize[3];
__constant__ int gBlockSize[3];//volume을 8칸씩 나눈 x, y 개수
__constant__ float gEye[3];
__constant__ float gDir[3];
__constant__ float gBackDir[3];
__constant__ float gCross[3];
__constant__ float gU[3];
__constant__ float gL[3];
__constant__ int gValidDir[3];
//__constant__ bool emptyBlock[32*32*29];
__constant__ bool emptyBlock[40*40*40]; //볼륨이 커지면 40으로 크게 잡자?

cudaArray* cudaArray = {0};
GLuint pbo = 0;     // EyeBody pixel buffer object
struct cudaGraphicsResource *cuda_pbo_resource;
//gpu 텍스쳐메모리
texture<unsigned char, 3, cudaReadModeNormalizedFloat> texPtr;

__inline__ __host__ __device__ void vec_add(float a[3], float b[3], float c[3]){
	c[0] = a[0] + b[0];
	c[1] = a[1] + b[1];
	c[2] = a[2] + b[2];
}
__inline__ __host__ __device__ void vec_sub(float a[3], float b[3], float c[3]){
	c[0] = a[0] - b[0];
	c[1] = a[1] - b[1];
	c[2] = a[2] - b[2];
}
__inline__ __host__ __device__ void s_product(float a[3], float size, float b[3]){
	b[0] = a[0] * size;
	b[1] = a[1] * size;
	b[2] = a[2] * size;
}
__inline__ __host__ __device__ void cross_product(float a[3], float b[3], float c[3])
{
	c[0] = a[1]*b[2] - a[2]*b[1];
	c[1] = a[2]*b[0] - a[0]*b[2];
	c[2] = a[0]*b[1] - a[1]*b[0];
}
__inline__ __host__ __device__ float vec_lenth(float a[3]){
	return sqrtf(a[0]*a[0] + a[1]*a[1] + a[2]*a[2]);
}
__inline__ __host__ __device__ float inner_product(float a[3], float b[3]){
	float buf = a[0]*b[0];
	buf += a[1]*b[1];
	buf += a[2]*b[2];
	return buf;
}
__inline__ __device__ void getNormal(float pos[3], float N[3]){
	N[0] = (tex3D(texPtr, pos[0]+1, pos[1], pos[2]) - tex3D(texPtr, pos[0]-1, pos[1], pos[2]))/2.0f;
	N[1] = (tex3D(texPtr, pos[0], pos[1]+1, pos[2]) - tex3D(texPtr, pos[0], pos[1]-1, pos[2]))/2.0f;
	N[2] = (tex3D(texPtr, pos[0], pos[1], pos[2]+1) - tex3D(texPtr, pos[0], pos[1], pos[2]-1))/2.0f;


	float len = vec_lenth(N);
	if(len != 0)//0으로 나눠지는걸 주의
		s_product(N, 1/vec_lenth(N), N); //단위벡터로 만들기
}
__inline__ __device__ float sign(float a){
	if(a > 0)
		return 1.0f;
	if(a < 0)
		return -1.0f;
	return 0.0f;
}

//parallel 함수
__inline__ __device__ bool IsIntersectRayBox1(float& startT, float& endT, float pos[3], int tx, int ty){
	float buf[3];
	float start[3];
	float dx[3], dy[3];
	float delta[3];
	float Max[3], Min[3];//x, y, z의 최대, 최소
	int j = 0;

	s_product(gCross, tx-gResolution*0.5f, dx);//x계산
	s_product(gU, ty-gResolution*0.5f, dy);//y계산
	vec_add(dx, dy, delta);//x+y = point
	vec_add(gEye, delta, start);//start+eye = start <- 시작지점

	for(int i = 0; i < 3; i++){
		float a, b;
		if(gValidDir[i] == 1){
			a = (gVolumeSize[i]-1 - start[i])/ gDir[i];
			b = (0.0f - start[i])/ gDir[i];
			

			if(a > b){//크기 정리
				Max[j] = a;
				Min[j] = b;
			}
			else{
				Max[j] = b;
				Min[j] = a;
			}
			j++;
		}
	}

	startT = Min[0];
	for(int i = 1; i < j; i++){//Min중 Max를 찾자. = startT가 된다.
		if(startT < Min[i])
			startT = Min[i];
	}
	startT += 0.001f;

	endT = Max[0];
	for(int i = 1; i < j; i++){//Max중 Min을 찾자. - endT가 된다.
		if(endT > Max[i])
			endT = Max[i];
	}
	endT -= 0.001f;

	//광선과 데이터가 만나는 점을 찾아보자.
	s_product(gDir, startT, buf);
	vec_add(start, buf, pos);

	//광선과 박스의 교점을 찾을수 없으면
	float maxBox[3] = {gVolumeSize[0], gVolumeSize[1], gVolumeSize[2]};
	float minBox[3] = {0.0f, 0.0f, 0.0f};

	float result1[3];
	float result2[3];

	for(int i = 0; i < 3; i++){
		result1[i] = sign(minBox[i]- pos[i]);
		result2[i] = sign(pos[i] - maxBox[i]);
	}
	float k = inner_product(result1, result2);
	if(k == 3.0f)
		return true;
	return false;

}
__inline__ __device__ int EmptySpaceLeap1(float pos[3]){
	//현재 박스가 비어있음을 확인하면 다음박스로 도약한다.
	int dt = 0;
	float currentBox[3] = {floorf(pos[0]*0.125f), floorf(pos[1]*0.125f), floorf(pos[2]*0.125f)};
	int currentBoxId = currentBox[0]+ currentBox[1]*gBlockSize[0] + currentBox[2]*gBlockSize[0]*gBlockSize[1];

	if(emptyBlock[currentBoxId]){
		while(true){
			dt++;
			vec_add(pos, gDir, pos);

			float forwardBox[3] = {floorf(pos[0]*0.125f), floorf(pos[1]*0.125f), floorf(pos[2]*0.125f)};
			int forwardBoxId = forwardBox[0]+ forwardBox[1]*gBlockSize[0] + forwardBox[2]*gBlockSize[0]*gBlockSize[2];

			//새로운 박스에 도달하면 빈공간도약검사를 끝낸다.
			if(currentBoxId != forwardBoxId)
				return dt;									
		}
	}	
	//비어있지않으면 알파블렌딩
	return dt;
}
__inline__ __device__ float AlphaBlending1(float4* PIT, float pos[3], float3& cAcc, const float aOld){
	unsigned char nowData = (unsigned char)(tex3D(texPtr, pos[0], pos[1], pos[2])*255.0f);		
	unsigned char nextData = (unsigned char)(tex3D(texPtr, pos[0]+gDir[0], pos[1]+gDir[1], pos[2]+gDir[2])*255.0f);
	
	if((nowData + nextData) == 0)
		return aOld;

	float N[3];// 픽셀의 법선벡터
	getNormal(pos, N);//법선벡터를 찾는다.

	float NL = fabs(inner_product(N, gL));//N과 L의 내적  - 절대값
	float NH = fabs(pow(inner_product(N, gDir), 16));
	float light = 0.2f + 0.7f*NL + 0.1f*NH; 
	if(light > 1.0f)
		light = 1.0f;

	int index = nowData*256 + nextData;
	light *= 1.0f-aOld;
	float alpha = PIT[index].w;
	cAcc.x += PIT[index].x*light;
	cAcc.y += PIT[index].y*light;
	cAcc.z += PIT[index].z*light;
	
	return 1.0f-(1.0f-aOld) * (1.0f-alpha);//알파값 리턴
}
__inline__ __device__ float3 RayTracing1(float4* PIT, float start[3], const float startT, const float endT){
	float pos[3] = {start[0], start[1], start[2]};
	float aNew = 0.0f;
	float aOld = 0.0f;
	float3 cAcc = {0};
	
	for(float t = startT; t <= endT; t+=1.0f){
		int dt = EmptySpaceLeap1(pos);

		//dt는 생략할 칸수 
		if(dt){//공간이 비어있다면			
			t+=dt-1.0f;
			continue;
		}		

		aNew = AlphaBlending1(PIT, pos, cAcc, aOld);		

		//Early Ray Termination
		if(aNew > 0.99f)
			break;	

		aOld = aNew;
		vec_add(pos, gDir, pos);
	}
	return cAcc;
}
__global__ void G_Parallel(unsigned char* tex, float4* PIT){
	//const int tx = blockDim.x*blockIdx.x + threadIdx.x;//영상의 x좌표
	//const int ty = blockDim.y*blockIdx.y + threadIdx.y;//영상의 y좌표
	//const int locTexture = ty*256 + tx;//일차원으로 계산된 좌표
	const int locTexture = blockDim.x*blockIdx.x + threadIdx.x;
	const int ty = locTexture/gResolution;
	const int tx = locTexture%gResolution;

	float pos[3];
	float startT, endT;
	//IsIntersectRayBox는 광선이 유효한지 확인하고 시작T와 끝T를 구한다.
	if(!IsIntersectRayBox1(startT, endT, pos, tx, ty)){
		tex[locTexture*3] = 0;
		tex[locTexture*3 + 1] = 0;
		tex[locTexture*3 + 2] = 0;
		return;//유효하지 않은 좌표면 스레드 종료
	}

	float3 cAcc = RayTracing1(PIT, pos, startT, endT);	

	tex[locTexture*3] = (unsigned char)(cAcc.x*255.0f);
	tex[locTexture*3 + 1] = (unsigned char)(cAcc.y*255.0f);
	tex[locTexture*3 + 2] = (unsigned char)(cAcc.z*255.0f);
}
//parallel 함수 끝

//perspective 함수
__inline__ __device__ bool IsIntersectRayBox2(float& startT, float& endT, float pos[3], float dir[3], int tx, int ty){
	float buf[3];
	float f[3];
	float cameraCenter[3];
	float start[3];
	float Max[3], Min[3];//x, y, z의 최대, 최소
	float dx[3], dy[3];
	float delta[3];
	int j = 0;

	s_product(gCross, tx-gResolution*0.5f, dx);//x계산
	s_product(dx, 0.005f, dx);
	s_product(gU, ty-gResolution*0.5f, dy);//y계산
	s_product(dy, 0.005f, dy);
	vec_add(dx, dy, delta);//dx+dy = delta

	s_product(gDir, 1.0f, f);
	vec_add(gEye, f, cameraCenter);
	vec_add(cameraCenter, delta, start);
	vec_sub(start, gEye, dir);//각 픽셀마다 다른 dir을 가진다.
	s_product(dir, 1/vec_lenth(dir), dir);

	for(int i = 0; i < 3; i++){
		float a, b;
		if(gValidDir[i] == 1){			
			a = (gVolumeSize[i]-1 - start[i])/ dir[i];
			b = (0.0f - start[i])/ dir[i];
			

			if(a > b){//크기 정리
				Max[j] = a;
				Min[j] = b;
			}
			else{
				Max[j] = b;
				Min[j] = a;
			}
			j++;
		}
	}

	endT = Max[0];
	for(int i = 1; i < j; i++){//Max중 Min을 찾자. - endT가 된다.
		if(endT > Max[i])
			endT = Max[i];
	}
	endT -= 0.001f;

	//볼륨크기
	float maxBox[3] = {gVolumeSize[0], gVolumeSize[1], gVolumeSize[2]};
	float minBox[3] = {0.0f, 0.0f, 0.0f};
	float result1[3];
	float result2[3];
	float k;

	for(int i = 0; i < 3; i++){
		result1[i] = sign(minBox[i]- start[i]);
		result2[i] = sign(start[i] - maxBox[i]);
	}
	k = inner_product(result1, result2);

	//start가 볼륨 내부에 있는지 확인한후에 내부이면 광선교차 검사할필요가 없다.
	if(k == 3.0f){//박스내부
		pos[0] = start[0];
		pos[1] = start[1];
		pos[2] = start[2];
		startT = 0.0f;
		return true;
	}

	//볼륨 외부에 있을경우 교차점도 찾아야한다.
	startT = Min[0];
	for(int i = 1; i < j; i++){//Min중 Max를 찾자. = startT가 된다.
		if(startT < Min[i])
			startT = Min[i];
	}
	startT += 0.001f;


	//볼륨 외부에 있을경우에는 광선과 박스가 만나는 지점을 찾아야함
	s_product(dir, startT, buf);
	vec_add(start, buf, pos);

	for(int i = 0; i < 3; i++){
		result1[i] = sign(minBox[i]- pos[i]);
		result2[i] = sign(pos[i] - maxBox[i]);
	}
	k = inner_product(result1, result2);

	if(k == 3.0f)//박스 내부임
		return true;
	return false;
}
__inline__ __device__ int EmptySpaceLeap2(float pos[3], float dir[3]){
	//현재 박스가 비어있음을 확인하면 다음박스로 도약한다.
	int dt = 0;
	float currentBox[3] = {floorf(pos[0]*0.125f), floorf(pos[1]*0.125f), floorf(pos[2]*0.125f)};
	float currentBoxId = currentBox[0]+ currentBox[1]*gBlockSize[0] + currentBox[2]*gBlockSize[0]*gBlockSize[1];

	if(emptyBlock[(int)currentBoxId]){
		while(true){
			dt++;
			vec_add(pos, dir, pos);

			float forwardBox[3] = {floorf(pos[0]*0.125f), floorf(pos[1]*0.125f), floorf(pos[2]*0.125f)};
			float forwardBoxId = forwardBox[0]+ forwardBox[1]*gBlockSize[0] + forwardBox[2]*gBlockSize[0]*gBlockSize[2];

			//새로운 박스에 도달하면 빈공간도약검사를 끝낸다.
			if(currentBoxId != forwardBoxId)
				break;						
		}
	}	
	//비어있지않으면 알파블렌딩
	return dt;
}
__inline__ __device__ float AlphaBlending2(float4* PIT, float pos[3], float dir[3], float3& cAcc, const float aOld){
	unsigned char nowData = (unsigned char)(tex3D(texPtr, pos[0], pos[1], pos[2])*255.0f);
	unsigned char nextData = (unsigned char)(tex3D(texPtr, pos[0]+dir[0], pos[1]+dir[1], pos[2]+dir[2])*255.0f);

	float N[3];// 픽셀의 법선벡터
	getNormal(pos, N);//법선벡터를 찾는다.

	float NL = fabs(inner_product(N, gL));//N과 L의 내적  - 절대값
	float NH = fabs(pow(inner_product(N, gDir), 16));
	float light = 0.2f + 0.7f*NL + 0.1f*NH; 
	if(light > 1.0f)
		light = 1.0f;

	int index = nowData*256 + nextData;
	light *= 1.0f-aOld;
	float alpha = PIT[index].w;
	cAcc.x += PIT[index].x*light;
	cAcc.y += PIT[index].y*light;
	cAcc.z += PIT[index].z*light;
	
	return 1.0f-(1.0f-aOld) * (1.0f-alpha);//알파값 리턴
}
__inline__ __device__ float3 RayTracing2(float4* PIT, float start[3], float dir[3], const float startT, const float endT){
	float pos[3] = {start[0], start[1], start[2]};
	float aNew = 0.0f;
	float aOld = 0.0f;
	float3 cAcc = {0};

	for(float t = startT; t <= endT; t+=1.0f){
		int dt = EmptySpaceLeap2(pos, dir);

		//비어있다면
		if(dt){
			t+=dt-1.0f;
			continue;
		}		

		//빈공간이 아니라면
		aNew = AlphaBlending2(PIT, pos, dir, cAcc, aOld);		

		//Early Ray Termination
		if(aNew > 0.99f)
			break;		
		aOld = aNew;

		vec_add(pos, dir, pos);
	}
	return cAcc;
}
__global__ void G_Perspective(unsigned char* tex, float4* PIT){
	const int locTexture = blockDim.x*blockIdx.x + threadIdx.x;
	const int ty = locTexture/gResolution;
	const int tx = locTexture%gResolution;

	float pos[3];
	float dir[3];
	float startT, endT;
	//IsIntersectRayBox는 광선이 유효한지 확인하고 시작T와 끝T를 구한다.
	if(!IsIntersectRayBox2(startT, endT, pos, dir, tx, ty)){
		tex[locTexture*3] = 0;
		tex[locTexture*3 + 1] = 0;
		tex[locTexture*3 + 2] = 0;
		return;//유효하지 않은 좌표면 스레드 종료
	}

	float3 cAcc = RayTracing2(PIT, pos, dir, startT, endT);	
	tex[locTexture*3] = (unsigned char)(cAcc.x*255.0f);
	tex[locTexture*3 + 1] = (unsigned char)(cAcc.y*255.0f);
	tex[locTexture*3 + 2] = (unsigned char)(cAcc.z*255.0f);
}
//perspective 함수 끝

__global__ void ChangeAlpha(float* alphaTable, int* transparentTable, int* aSAT){
	int i = threadIdx.x;

	if(alphaTable[i] == 0)
		transparentTable[i] = 0;
	else		
		transparentTable[i] = 1;
	
	__syncthreads();
	for(int j = i; j < 256; j++)
		atomicAdd(&aSAT[j+1], transparentTable[i]);
	if(i == 0)
		aSAT[0] = 0;
}
__global__ void InitMinMaxEmptyBlock(unsigned char* emptyBlockMax, unsigned char* emptyBlockMin){
	int i = blockDim.x*blockIdx.x + threadIdx.x;
	int bz = i/(gBlockSize[0]*gBlockSize[1]);
	int by = (i%(int)(gBlockSize[0]*gBlockSize[1]))/gBlockSize[0];
	int bx = i%(int)gBlockSize[1];


	float m = 1.0f;
	float M = 0.0f;
	int vz, vy, vx;
	for(vz = bz*8; vz <= bz*8 + 8; vz++){
		if(vz > gVolumeSize[2]-1)
			break;
		for(vy = by*8; vy <= by*8 + 8; vy++){  
			for(vx = bx*8; vx <= bx*8 + 8; vx++){         
				float data = tex3D(texPtr, vx, vy, vz);
				M = max(M, data);
				m = min(m, data);
			}
		}
	}

	emptyBlockMin[i] = (unsigned char)(m*255);
	emptyBlockMax[i] = (unsigned char)(M*255);
}
__global__ void InitEmptyBlock(bool* emptyBlock, unsigned char* emptyBlockMax, unsigned char* emptyBlockMin, int* aSAT){
	int i = blockDim.x*blockIdx.x + threadIdx.x;
	int *pSAT = &(aSAT[1]);

	emptyBlock[i] = (pSAT[emptyBlockMax[i]] == pSAT[emptyBlockMin[i]-1]) ? true : false;
}
__global__ void InitPreIntegration(float4* pit, float* alphaTable, float3* colorTable){
	int i = threadIdx.x;

	if(i == 255){
		for(int j = 0; j < 256; j++){
			float A = alphaTable[j];
			int index = j*256+j;
			pit[index].w = A;
			pit[index].x = colorTable[j].x * A;
			pit[index].y = colorTable[j].y * A;
			pit[index].z = colorTable[j].z * A;
		}
		return;
	}
	

	int k = 255 - i;
	float samplingTable[256];
	for(int j = 0; j < 256; j++){
		float A = alphaTable[j];//최소값+j번째의 alpha값을 찾는다. s == e면 진행할필요없음
		A = 1.0f - pow(1.0f - A, 1.0f/k);
		samplingTable[j] = A;
	}
	int e = 255-i;
	int s = 0;
	for( ; s <= i; s++,e++){
		float A = 0, aOld = 0, aNew = 0;
		float3 cAcc = {0};
		//정사각형의 대각선 /을 기준으로 왼쪽상단
		for(int j = s; j < e; j++){
			float k = 1.0f - aOld;
			A = samplingTable[j];
			aNew = 1.0f - k*(1.0f - A);
			cAcc.x += k*colorTable[j].x*A;
			cAcc.y += k*colorTable[j].y*A;
			cAcc.z += k*colorTable[j].z*A;
			if(aNew > 0.99f)
				break;
			aOld = aNew;
		}
		int index = s*256 + e;
		pit[index].x = cAcc.x;
		pit[index].y = cAcc.y;
		pit[index].z = cAcc.z;
		pit[index].w = aNew;

		//정사각형의 대각선 /을 기준으로 오른쪽하단
		aOld = 0, aNew = 0;
		cAcc.x = cAcc.y = cAcc.z = 0;
		for(int j = e; j > s; j--){
			float k = 1.0f - aOld;
			A = samplingTable[j];
			aNew = 1.0f - k*(1.0f - A);
			cAcc.x += k*colorTable[j].x*A;
			cAcc.y += k*colorTable[j].y*A;
			cAcc.z += k*colorTable[j].z*A;
			if(aNew > 0.99f)
				break;
			aOld = aNew;
		}
		index = e*256 + s;
		pit[index].x = cAcc.x;
		pit[index].y = cAcc.y;
		pit[index].z = cAcc.z;
		pit[index].w = aNew;
	}


}


GPUrender::GPUrender(){
	PerspectiveView = false;
	eye[0] = eye[1] = eye[2] = 0;
	float sqr = 1/sqrtf(3);
	L[0] = L[1] = L[2] = sqr;
	up[0] = up[1] = 0;
	up[2] = -1;
	validDir[0] = validDir[1] = validDir[2] = 0;
	zoom = 1.0f;
	resolution = 256;
	pbo = 0;
}

void GPUrender::InitColor(){
	float* gAlphaTable;
	int* gTransparentTable;
	int* gSAT;
	float3* gColorTable;
	bool* gEmptyBlock;
	float time;
	cudaEvent_t start, end;
	cudaEventCreate(&start);
	cudaEventCreate(&end);	


	cudaMalloc((void**)&gSAT, sizeof(int)*257);
	cudaMalloc((void**)&gAlphaTable, sizeof(float)*256);
	cudaMalloc((void**)&gTransparentTable, sizeof(int)*256);
	cudaMalloc((void**)&gColorTable, sizeof(float3)*256);


	cudaMemcpy(gAlphaTable, alphaTable, sizeof(float)*256, cudaMemcpyHostToDevice);
	cudaMemcpy(gColorTable, colorTable, sizeof(float3)*256, cudaMemcpyHostToDevice);

	cudaEventRecord(start, 0);
	ChangeAlpha<<<1, 256>>>(gAlphaTable, gTransparentTable, gSAT);


	cudaEventRecord(end, 0);
	cudaEventSynchronize(end);
	cudaEventElapsedTime(&time, start, end);
	printf("InitAlpha time = %fms\n", time);

	cudaFree(gTransparentTable);

	cudaMalloc((void**)&gEmptyBlock, sizeof(bool)*32*32*29);

	cudaMemset(gEmptyBlock, 0, 32*32*29*sizeof(bool));
	cudaEventRecord(start, 0);
	InitEmptyBlock<<<58, 512>>>(gEmptyBlock, gEmptyBlockMax, gEmptyBlockMin, gSAT);
	cudaEventRecord(end, 0);
	cudaEventSynchronize(end);
	cudaEventElapsedTime(&time, start, end);
	printf("InitEmptyBlock time = %fms\n", time);
	//상수메모리로 빈공간블록정보 보낸다.
	cudaMemset(emptyBlock, 0, 32*32*29*sizeof(bool));
	cudaMemcpyToSymbol(emptyBlock, gEmptyBlock, sizeof(bool)*32*32*29, 0, cudaMemcpyDeviceToDevice);

	cudaFree(gEmptyBlock);
	cudaFree(gSAT);

	cudaMalloc((void**)&gPIT, sizeof(float4)*256*256);

	

	cudaEventRecord(start, 0);
	InitPreIntegration<<<1, 256>>>(gPIT, gAlphaTable, gColorTable);
	cudaEventRecord(end, 0);
	cudaEventSynchronize(end);
	cudaEventElapsedTime(&time, start, end);
	printf("InitPreintegration time = %fms\n", time);

	cudaEventDestroy(start);
	cudaEventDestroy(end);
	cudaFree(gAlphaTable);
	cudaFree(gColorTable);
}
void GPUrender::InitGpuConst(){
	vec_sub(at, eye, dir); //dir 벡터 생성
	s_product(dir, 1.0f/vec_lenth(dir), dir); //dir을 정규화

	cross_product(up, dir, cross);//cross벡터 생성 
	s_product(cross, (256.0f/resolution)*zoom/vec_lenth(cross), cross);//cross벡터 정규화 <- 시점의 x좌표
	//s_product(cross, zoom, cross);//배율

	cross_product(dir, cross, u);//u벡터 생성 
	s_product(u, (256.0f/resolution)*zoom/vec_lenth(u), u);//u벡터 정규화 <- 시점의 y좌표
	//s_product(u, zoom, u);//배율

	if(dir[0] != 0)//x방향이 0이 아니면
		validDir[0] = 1;
	if(dir[1] != 0)//y방향이 0이 아니면
		validDir[1] = 1;
	if(dir[2] != 0)//z방향이 0이 아니면
		validDir[2] = 1;

	//gpu에 상수메모리로 넣음
	int const_size = sizeof(float)*3;//상수메모리에 사용할 크기
	cudaMemcpyToSymbol(gEye, eye, const_size);
	cudaMemcpyToSymbol(gDir, dir, const_size);
	cudaMemcpyToSymbol(gCross, cross, const_size);	
	cudaMemcpyToSymbol(gU, u, const_size);
	cudaMemcpyToSymbol(gL, L, const_size);
	cudaMemcpyToSymbol(gValidDir, validDir, sizeof(int)*3);
	cudaMemcpyToSymbol(gResolution, &resolution, sizeof(int)*1);
	float backDir[3];
	s_product(dir, 1.3, backDir);
	cudaMemcpyToSymbol(gBackDir, backDir, const_size);
}
void GPUrender::InitPixelBuffer(){
	glGenBuffers(1, &pbo);//버퍼 객체를 생성한다.
	glBindBuffer(GL_PIXEL_UNPACK_BUFFER, pbo);
	//버퍼에 타겟을 생성함 (GLenum target,GLuint buffer)
	//타겟에 대한 API는 https://www.EyeBody.org/sdk/docs/man/html/glBindBuffer.xhtml
	//GL_PIXEL_UNPACK_BUFFER는 Texture data source목적임
	glBufferData(GL_PIXEL_UNPACK_BUFFER, 
					3*resolution*resolution*sizeof(GLubyte), 
					0, 
					GL_STREAM_DRAW);
	//바인드된 버퍼에 데이터생성(메모리 생성함)

	//glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

	cudaGraphicsGLRegisterBuffer(&cuda_pbo_resource, 
								pbo, 
								cudaGraphicsMapFlagsNone);
}

void GPUrender::Rendering() {
	unsigned char* gTex;
	//cudaError_t result;//에러검사
	cudaEvent_t start, end;

	float time;

	//EyeBody과 텍스쳐를 연동하는 코드
	cudaGraphicsMapResources(1, &cuda_pbo_resource, 0);//1개 맵핑
	cudaGraphicsResourceGetMappedPointer((void **)&gTex, NULL, cuda_pbo_resource);//메모리 포인터를 얻어온다.(맵핑한다)

	//x개수 = 8*32 = 256, y개수 = 16*16 = 256 => Texture크기
	//dim3 Dg(8, 16, 1);
	//dim3 Db(32, 16, 1);//32*16 = 512최대쓰레드 사용
	int block = resolution*resolution/512;

	//시간측정 코드
	cudaEventCreate(&start);
	cudaEventCreate(&end);	

	cudaEventRecord(start, 0);
	//커널함수 호출
	if(PerspectiveView)
		G_Perspective<<<block, 512>>>(gTex, gPIT);
	else
		G_Parallel<<<block, 512>>>(gTex, gPIT);
	
	cudaEventRecord(end, 0);

	cudaEventSynchronize(end);
	cudaEventElapsedTime(&time, start, end);
	cudaEventDestroy(start);
	cudaEventDestroy(end);
	printf("Renter time = %fms\n", time);
	//시간측정 코드 끝

	//맵핑해제하면 EyeBody에서 텍스쳐출력
	cudaGraphicsUnmapResources(1, &cuda_pbo_resource, 0);

}
void GPUrender::DrawTexture(){
	glClear(GL_COLOR_BUFFER_BIT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexImage2D(GL_TEXTURE_2D, 0, 3, resolution, resolution, 0, GL_RGB, GL_UNSIGNED_BYTE, NULL);
	glEnable(GL_TEXTURE_2D);
	glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_DECAL);
	glBegin(GL_QUADS);
		glTexCoord2f(0.0, 0.0); glVertex2f(-1.0, -1.0);
		glTexCoord2f(0.0, 1.0); glVertex2f(-1.0, 1.0);
		glTexCoord2f(1.0, 1.0); glVertex2f(1.0, 1.0);
		glTexCoord2f(1.0, 0.0); glVertex2f(1.0, -1.0);
	glEnd();
}

void GPUrender::MouseRotateEye(int x, int y){
	/*	1. eye와 at의 거리(A)를 계산한다.
		2. eye을 현재 cross와 up으로 x,y만큼 움직인다
		3. 변경된 eye와 at의 거리를 A가 되도록 만든다.
	*/
	//1번
	float A = sqrtf((eye[0]-at[0])*(eye[0]-at[0]) + (eye[1]-at[1])*(eye[1]-at[1]) + (eye[2]-at[2])*(eye[2]-at[2]));
	//2번
	eye[0] += -x*cross[0] + y*u[0];
	eye[1] += -x*cross[1] + y*u[1];
	eye[2] += -x*cross[2] + y*u[2];

	vec_sub(at, eye, dir); //dir 벡터 생성
	s_product(dir, 1.0f/vec_lenth(dir), dir); //dir을 정규화
	//3번
	s_product(dir, A, dir);
	vec_sub(at, dir, eye);

	InitGpuConst();
}
void GPUrender::ForwardEye(bool forward){
	if(forward){
		if(PerspectiveView){
			float buf[3];
			s_product(dir, 8, buf);
			vec_add(eye, buf, eye);
		}
		else
			zoom /= 1.1f;
	}
	else{
		if(PerspectiveView){
			float buf[3];
			s_product(dir, 8, buf);
			vec_sub(eye, buf, eye);
		}			
		else
			zoom *= 1.1f;
	}

	printf("eye (%.3f, %.3f, %.3f)\n", eye[0], eye[1], eye[2]);
	printf("dir (%.3f, %.3f, %.3f)\n", dir[0], dir[1], dir[2]);
	InitGpuConst();
}
void GPUrender::ChangeResolution(int n){

	resolution = n;
	InitPixelBuffer();
	InitGpuConst();
}
void GPUrender::ChangeView(bool perspective){
	PerspectiveView = perspective;
}
void GPUrender::InitVolume(unsigned char* Volume, int size[3]){
	volume = Volume;
	volumeSize[0] = size[0];
	volumeSize[1] = size[1];
	volumeSize[2] = size[2];
	at[0] = size[0]/2;
	at[1] = size[1]/2;
	at[2] = size[2]/2;

	glewInit();

	cudaMemcpyToSymbol(gVolumeSize, volumeSize, sizeof(int)*3);

	int iBlockSize[3] = {volumeSize[0]/8, volumeSize[1]/8, volumeSize[2]/8};
	if(volumeSize[0]%8)
		iBlockSize[0]+=1;
	if(volumeSize[1]%8)
		iBlockSize[1]+=1;
	if(volumeSize[2]%8)
		iBlockSize[2]+=1;

	int fBlockSize[3] = {iBlockSize[0], iBlockSize[1], iBlockSize[2]};
	cudaMemcpyToSymbol(gBlockSize, fBlockSize, sizeof(int)*3);

	cudaChannelFormatDesc channelDesc = cudaCreateChannelDesc<unsigned char>();	
	cudaExtent eVolumeSize = make_cudaExtent(volumeSize[0], volumeSize[1], volumeSize[2]);

	cudaMalloc3DArray(&cudaArray, &channelDesc, eVolumeSize, 0);
	cudaMemcpy3DParms params = {0};
	params.extent = eVolumeSize;
	params.dstArray = cudaArray;
	params.kind = cudaMemcpyHostToDevice;
	params.srcPtr = make_cudaPitchedPtr((void*)volume, sizeof(unsigned char)*volumeSize[0], volumeSize[0], volumeSize[1]);

	cudaMemcpy3D(&params);

	texPtr.filterMode=cudaFilterModeLinear;//linear는 texture가 float형만 가능하다
	texPtr.addressMode[0]=cudaAddressModeWrap;
	texPtr.addressMode[1]=cudaAddressModeWrap;
	texPtr.addressMode[2]=cudaAddressModeWrap;

	cudaBindTextureToArray(texPtr, cudaArray, channelDesc); 
	

	
	float time;
	cudaEvent_t start, end;
	cudaEventCreate(&start);
	cudaEventCreate(&end);
	
	cudaMalloc((void**)&gEmptyBlockMax, sizeof(unsigned char)*iBlockSize[0]*iBlockSize[1]*iBlockSize[2]);
	cudaMalloc((void**)&gEmptyBlockMin, sizeof(unsigned char)*iBlockSize[0]*iBlockSize[1]*iBlockSize[2]);
	int block = iBlockSize[0]*iBlockSize[1]*iBlockSize[2]/512;
	if((iBlockSize[0]*iBlockSize[1]*iBlockSize[2])%512)
		block++;
	cudaEventRecord(start, 0);
	InitMinMaxEmptyBlock<<<block, 512>>>(gEmptyBlockMax, gEmptyBlockMin);
	cudaEventRecord(end, 0);
	cudaEventSynchronize(end);
	cudaEventElapsedTime(&time, start, end);
	printf("InitMinMaxEmptyBlock time = %fms\n", time);
}
void GPUrender::InitColorTable(float3* ColorTable){
	colorTable = ColorTable;
}
void GPUrender::InitAlphaTable(float* AlphaTable){
	alphaTable = AlphaTable;
}
void GPUrender::EyeBodyCancel(){
	if (pbo) {
		cudaGraphicsUnregisterResource(cuda_pbo_resource);//완전히 연결끊는다
		glDeleteBuffers(1, &pbo);
	}
	cudaUnbindTexture(texPtr); 
	cudaFreeArray(cudaArray); 
}