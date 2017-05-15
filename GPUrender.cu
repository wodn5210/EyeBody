#include "GPUrender.cuh"
//������Ʈ 20, �ڵ����� 12


//gpu ����޸�
__constant__ int gResolution;
__constant__ int gVolumeSize[3];
__constant__ int gBlockSize[3];//volume�� 8ĭ�� ���� x, y ����
__constant__ float gEye[3];
__constant__ float gDir[3];
__constant__ float gBackDir[3];
__constant__ float gCross[3];
__constant__ float gU[3];
__constant__ float gL[3];
__constant__ int gValidDir[3];
//__constant__ bool emptyBlock[32*32*29];
__constant__ bool emptyBlock[40*40*40]; //������ Ŀ���� 40���� ũ�� ����?

cudaArray* cudaArray = {0};
GLuint pbo = 0;     // EyeBody pixel buffer object
struct cudaGraphicsResource *cuda_pbo_resource;
//gpu �ؽ��ĸ޸�
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
	if(len != 0)//0���� �������°� ����
		s_product(N, 1/vec_lenth(N), N); //�������ͷ� �����
}
__inline__ __device__ float sign(float a){
	if(a > 0)
		return 1.0f;
	if(a < 0)
		return -1.0f;
	return 0.0f;
}

//parallel �Լ�
__inline__ __device__ bool IsIntersectRayBox1(float& startT, float& endT, float pos[3], int tx, int ty){
	float buf[3];
	float start[3];
	float dx[3], dy[3];
	float delta[3];
	float Max[3], Min[3];//x, y, z�� �ִ�, �ּ�
	int j = 0;

	s_product(gCross, tx-gResolution*0.5f, dx);//x���
	s_product(gU, ty-gResolution*0.5f, dy);//y���
	vec_add(dx, dy, delta);//x+y = point
	vec_add(gEye, delta, start);//start+eye = start <- ��������

	for(int i = 0; i < 3; i++){
		float a, b;
		if(gValidDir[i] == 1){
			a = (gVolumeSize[i]-1 - start[i])/ gDir[i];
			b = (0.0f - start[i])/ gDir[i];
			

			if(a > b){//ũ�� ����
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
	for(int i = 1; i < j; i++){//Min�� Max�� ã��. = startT�� �ȴ�.
		if(startT < Min[i])
			startT = Min[i];
	}
	startT += 0.001f;

	endT = Max[0];
	for(int i = 1; i < j; i++){//Max�� Min�� ã��. - endT�� �ȴ�.
		if(endT > Max[i])
			endT = Max[i];
	}
	endT -= 0.001f;

	//������ �����Ͱ� ������ ���� ã�ƺ���.
	s_product(gDir, startT, buf);
	vec_add(start, buf, pos);

	//������ �ڽ��� ������ ã���� ������
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
	//���� �ڽ��� ��������� Ȯ���ϸ� �����ڽ��� �����Ѵ�.
	int dt = 0;
	float currentBox[3] = {floorf(pos[0]*0.125f), floorf(pos[1]*0.125f), floorf(pos[2]*0.125f)};
	int currentBoxId = currentBox[0]+ currentBox[1]*gBlockSize[0] + currentBox[2]*gBlockSize[0]*gBlockSize[1];

	if(emptyBlock[currentBoxId]){
		while(true){
			dt++;
			vec_add(pos, gDir, pos);

			float forwardBox[3] = {floorf(pos[0]*0.125f), floorf(pos[1]*0.125f), floorf(pos[2]*0.125f)};
			int forwardBoxId = forwardBox[0]+ forwardBox[1]*gBlockSize[0] + forwardBox[2]*gBlockSize[0]*gBlockSize[2];

			//���ο� �ڽ��� �����ϸ� ���������˻縦 ������.
			if(currentBoxId != forwardBoxId)
				return dt;									
		}
	}	
	//������������� ���ĺ���
	return dt;
}
__inline__ __device__ float AlphaBlending1(float4* PIT, float pos[3], float3& cAcc, const float aOld){
	unsigned char nowData = (unsigned char)(tex3D(texPtr, pos[0], pos[1], pos[2])*255.0f);		
	unsigned char nextData = (unsigned char)(tex3D(texPtr, pos[0]+gDir[0], pos[1]+gDir[1], pos[2]+gDir[2])*255.0f);
	
	if((nowData + nextData) == 0)
		return aOld;

	float N[3];// �ȼ��� ��������
	getNormal(pos, N);//�������͸� ã�´�.

	float NL = fabs(inner_product(N, gL));//N�� L�� ����  - ���밪
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
	
	return 1.0f-(1.0f-aOld) * (1.0f-alpha);//���İ� ����
}
__inline__ __device__ float3 RayTracing1(float4* PIT, float start[3], const float startT, const float endT){
	float pos[3] = {start[0], start[1], start[2]};
	float aNew = 0.0f;
	float aOld = 0.0f;
	float3 cAcc = {0};
	
	for(float t = startT; t <= endT; t+=1.0f){
		int dt = EmptySpaceLeap1(pos);

		//dt�� ������ ĭ�� 
		if(dt){//������ ����ִٸ�			
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
	//const int tx = blockDim.x*blockIdx.x + threadIdx.x;//������ x��ǥ
	//const int ty = blockDim.y*blockIdx.y + threadIdx.y;//������ y��ǥ
	//const int locTexture = ty*256 + tx;//���������� ���� ��ǥ
	const int locTexture = blockDim.x*blockIdx.x + threadIdx.x;
	const int ty = locTexture/gResolution;
	const int tx = locTexture%gResolution;

	float pos[3];
	float startT, endT;
	//IsIntersectRayBox�� ������ ��ȿ���� Ȯ���ϰ� ����T�� ��T�� ���Ѵ�.
	if(!IsIntersectRayBox1(startT, endT, pos, tx, ty)){
		tex[locTexture*3] = 0;
		tex[locTexture*3 + 1] = 0;
		tex[locTexture*3 + 2] = 0;
		return;//��ȿ���� ���� ��ǥ�� ������ ����
	}

	float3 cAcc = RayTracing1(PIT, pos, startT, endT);	

	tex[locTexture*3] = (unsigned char)(cAcc.x*255.0f);
	tex[locTexture*3 + 1] = (unsigned char)(cAcc.y*255.0f);
	tex[locTexture*3 + 2] = (unsigned char)(cAcc.z*255.0f);
}
//parallel �Լ� ��

//perspective �Լ�
__inline__ __device__ bool IsIntersectRayBox2(float& startT, float& endT, float pos[3], float dir[3], int tx, int ty){
	float buf[3];
	float f[3];
	float cameraCenter[3];
	float start[3];
	float Max[3], Min[3];//x, y, z�� �ִ�, �ּ�
	float dx[3], dy[3];
	float delta[3];
	int j = 0;

	s_product(gCross, tx-gResolution*0.5f, dx);//x���
	s_product(dx, 0.005f, dx);
	s_product(gU, ty-gResolution*0.5f, dy);//y���
	s_product(dy, 0.005f, dy);
	vec_add(dx, dy, delta);//dx+dy = delta

	s_product(gDir, 1.0f, f);
	vec_add(gEye, f, cameraCenter);
	vec_add(cameraCenter, delta, start);
	vec_sub(start, gEye, dir);//�� �ȼ����� �ٸ� dir�� ������.
	s_product(dir, 1/vec_lenth(dir), dir);

	for(int i = 0; i < 3; i++){
		float a, b;
		if(gValidDir[i] == 1){			
			a = (gVolumeSize[i]-1 - start[i])/ dir[i];
			b = (0.0f - start[i])/ dir[i];
			

			if(a > b){//ũ�� ����
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
	for(int i = 1; i < j; i++){//Max�� Min�� ã��. - endT�� �ȴ�.
		if(endT > Max[i])
			endT = Max[i];
	}
	endT -= 0.001f;

	//����ũ��
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

	//start�� ���� ���ο� �ִ��� Ȯ�����Ŀ� �����̸� �������� �˻����ʿ䰡 ����.
	if(k == 3.0f){//�ڽ�����
		pos[0] = start[0];
		pos[1] = start[1];
		pos[2] = start[2];
		startT = 0.0f;
		return true;
	}

	//���� �ܺο� ������� �������� ã�ƾ��Ѵ�.
	startT = Min[0];
	for(int i = 1; i < j; i++){//Min�� Max�� ã��. = startT�� �ȴ�.
		if(startT < Min[i])
			startT = Min[i];
	}
	startT += 0.001f;


	//���� �ܺο� ������쿡�� ������ �ڽ��� ������ ������ ã�ƾ���
	s_product(dir, startT, buf);
	vec_add(start, buf, pos);

	for(int i = 0; i < 3; i++){
		result1[i] = sign(minBox[i]- pos[i]);
		result2[i] = sign(pos[i] - maxBox[i]);
	}
	k = inner_product(result1, result2);

	if(k == 3.0f)//�ڽ� ������
		return true;
	return false;
}
__inline__ __device__ int EmptySpaceLeap2(float pos[3], float dir[3]){
	//���� �ڽ��� ��������� Ȯ���ϸ� �����ڽ��� �����Ѵ�.
	int dt = 0;
	float currentBox[3] = {floorf(pos[0]*0.125f), floorf(pos[1]*0.125f), floorf(pos[2]*0.125f)};
	float currentBoxId = currentBox[0]+ currentBox[1]*gBlockSize[0] + currentBox[2]*gBlockSize[0]*gBlockSize[1];

	if(emptyBlock[(int)currentBoxId]){
		while(true){
			dt++;
			vec_add(pos, dir, pos);

			float forwardBox[3] = {floorf(pos[0]*0.125f), floorf(pos[1]*0.125f), floorf(pos[2]*0.125f)};
			float forwardBoxId = forwardBox[0]+ forwardBox[1]*gBlockSize[0] + forwardBox[2]*gBlockSize[0]*gBlockSize[2];

			//���ο� �ڽ��� �����ϸ� ���������˻縦 ������.
			if(currentBoxId != forwardBoxId)
				break;						
		}
	}	
	//������������� ���ĺ���
	return dt;
}
__inline__ __device__ float AlphaBlending2(float4* PIT, float pos[3], float dir[3], float3& cAcc, const float aOld){
	unsigned char nowData = (unsigned char)(tex3D(texPtr, pos[0], pos[1], pos[2])*255.0f);
	unsigned char nextData = (unsigned char)(tex3D(texPtr, pos[0]+dir[0], pos[1]+dir[1], pos[2]+dir[2])*255.0f);

	float N[3];// �ȼ��� ��������
	getNormal(pos, N);//�������͸� ã�´�.

	float NL = fabs(inner_product(N, gL));//N�� L�� ����  - ���밪
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
	
	return 1.0f-(1.0f-aOld) * (1.0f-alpha);//���İ� ����
}
__inline__ __device__ float3 RayTracing2(float4* PIT, float start[3], float dir[3], const float startT, const float endT){
	float pos[3] = {start[0], start[1], start[2]};
	float aNew = 0.0f;
	float aOld = 0.0f;
	float3 cAcc = {0};

	for(float t = startT; t <= endT; t+=1.0f){
		int dt = EmptySpaceLeap2(pos, dir);

		//����ִٸ�
		if(dt){
			t+=dt-1.0f;
			continue;
		}		

		//������� �ƴ϶��
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
	//IsIntersectRayBox�� ������ ��ȿ���� Ȯ���ϰ� ����T�� ��T�� ���Ѵ�.
	if(!IsIntersectRayBox2(startT, endT, pos, dir, tx, ty)){
		tex[locTexture*3] = 0;
		tex[locTexture*3 + 1] = 0;
		tex[locTexture*3 + 2] = 0;
		return;//��ȿ���� ���� ��ǥ�� ������ ����
	}

	float3 cAcc = RayTracing2(PIT, pos, dir, startT, endT);	
	tex[locTexture*3] = (unsigned char)(cAcc.x*255.0f);
	tex[locTexture*3 + 1] = (unsigned char)(cAcc.y*255.0f);
	tex[locTexture*3 + 2] = (unsigned char)(cAcc.z*255.0f);
}
//perspective �Լ� ��

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
		float A = alphaTable[j];//�ּҰ�+j��°�� alpha���� ã�´�. s == e�� �������ʿ����
		A = 1.0f - pow(1.0f - A, 1.0f/k);
		samplingTable[j] = A;
	}
	int e = 255-i;
	int s = 0;
	for( ; s <= i; s++,e++){
		float A = 0, aOld = 0, aNew = 0;
		float3 cAcc = {0};
		//���簢���� �밢�� /�� �������� ���ʻ��
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

		//���簢���� �밢�� /�� �������� �������ϴ�
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
	//����޸𸮷� ������������ ������.
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
	vec_sub(at, eye, dir); //dir ���� ����
	s_product(dir, 1.0f/vec_lenth(dir), dir); //dir�� ����ȭ

	cross_product(up, dir, cross);//cross���� ���� 
	s_product(cross, (256.0f/resolution)*zoom/vec_lenth(cross), cross);//cross���� ����ȭ <- ������ x��ǥ
	//s_product(cross, zoom, cross);//����

	cross_product(dir, cross, u);//u���� ���� 
	s_product(u, (256.0f/resolution)*zoom/vec_lenth(u), u);//u���� ����ȭ <- ������ y��ǥ
	//s_product(u, zoom, u);//����

	if(dir[0] != 0)//x������ 0�� �ƴϸ�
		validDir[0] = 1;
	if(dir[1] != 0)//y������ 0�� �ƴϸ�
		validDir[1] = 1;
	if(dir[2] != 0)//z������ 0�� �ƴϸ�
		validDir[2] = 1;

	//gpu�� ����޸𸮷� ����
	int const_size = sizeof(float)*3;//����޸𸮿� ����� ũ��
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
	glGenBuffers(1, &pbo);//���� ��ü�� �����Ѵ�.
	glBindBuffer(GL_PIXEL_UNPACK_BUFFER, pbo);
	//���ۿ� Ÿ���� ������ (GLenum target,GLuint buffer)
	//Ÿ�ٿ� ���� API�� https://www.EyeBody.org/sdk/docs/man/html/glBindBuffer.xhtml
	//GL_PIXEL_UNPACK_BUFFER�� Texture data source������
	glBufferData(GL_PIXEL_UNPACK_BUFFER, 
					3*resolution*resolution*sizeof(GLubyte), 
					0, 
					GL_STREAM_DRAW);
	//���ε�� ���ۿ� �����ͻ���(�޸� ������)

	//glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

	cudaGraphicsGLRegisterBuffer(&cuda_pbo_resource, 
								pbo, 
								cudaGraphicsMapFlagsNone);
}

void GPUrender::Rendering() {
	unsigned char* gTex;
	//cudaError_t result;//�����˻�
	cudaEvent_t start, end;

	float time;

	//EyeBody�� �ؽ��ĸ� �����ϴ� �ڵ�
	cudaGraphicsMapResources(1, &cuda_pbo_resource, 0);//1�� ����
	cudaGraphicsResourceGetMappedPointer((void **)&gTex, NULL, cuda_pbo_resource);//�޸� �����͸� ���´�.(�����Ѵ�)

	//x���� = 8*32 = 256, y���� = 16*16 = 256 => Textureũ��
	//dim3 Dg(8, 16, 1);
	//dim3 Db(32, 16, 1);//32*16 = 512�ִ뾲���� ���
	int block = resolution*resolution/512;

	//�ð����� �ڵ�
	cudaEventCreate(&start);
	cudaEventCreate(&end);	

	cudaEventRecord(start, 0);
	//Ŀ���Լ� ȣ��
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
	//�ð����� �ڵ� ��

	//���������ϸ� EyeBody���� �ؽ������
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
	/*	1. eye�� at�� �Ÿ�(A)�� ����Ѵ�.
		2. eye�� ���� cross�� up���� x,y��ŭ �����δ�
		3. ����� eye�� at�� �Ÿ��� A�� �ǵ��� �����.
	*/
	//1��
	float A = sqrtf((eye[0]-at[0])*(eye[0]-at[0]) + (eye[1]-at[1])*(eye[1]-at[1]) + (eye[2]-at[2])*(eye[2]-at[2]));
	//2��
	eye[0] += -x*cross[0] + y*u[0];
	eye[1] += -x*cross[1] + y*u[1];
	eye[2] += -x*cross[2] + y*u[2];

	vec_sub(at, eye, dir); //dir ���� ����
	s_product(dir, 1.0f/vec_lenth(dir), dir); //dir�� ����ȭ
	//3��
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

	texPtr.filterMode=cudaFilterModeLinear;//linear�� texture�� float���� �����ϴ�
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
		cudaGraphicsUnregisterResource(cuda_pbo_resource);//������ ������´�
		glDeleteBuffers(1, &pbo);
	}
	cudaUnbindTexture(texPtr); 
	cudaFreeArray(cudaArray); 
}