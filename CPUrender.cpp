#include "CPUrender.h"
#include <math.h>
#include <time.h>
#define MAX(a,b) (a > b) ? a : b
#define MIN(a,b) (a > b) ? b : a

CPUrender::CPUrender(){
	PerspectiveView = false;
	eye[0] = eye[1] = eye[2] = 0;
	float sqr = 1/sqrtf(3);
	L[0] = L[1] = L[2] = sqr;
	up[0] = up[1] = 0;
	up[2] = -1;
	validDir[0] = validDir[1] = validDir[2] = 0;
	zoom = 1.0f;
	resolution = 256;
}
void CPUrender::vec_add(float a[3], float b[3], float c[3]){
	c[0] = a[0] + b[0];
	c[1] = a[1] + b[1];
	c[2] = a[2] + b[2];
}
void CPUrender::vec_sub(float a[3], float b[3], float c[3]){
	c[0] = a[0] - b[0];
	c[1] = a[1] - b[1];
	c[2] = a[2] - b[2];
}
void CPUrender::s_product(float a[3], float size, float b[3]){
	b[0] = a[0] * size;
	b[1] = a[1] * size;
	b[2] = a[2] * size;
}
void CPUrender::cross_product(float a[3], float b[3], float c[3]){
	c[0] = a[1]*b[2] - a[2]*b[1];
	c[1] = a[2]*b[0] - a[0]*b[2];
	c[2] = a[0]*b[1] - a[1]*b[0];
}
float CPUrender::vec_lenth(float a[3]){
	return sqrtf(a[0]*a[0] + a[1]*a[1] + a[2]*a[2]);
}
float CPUrender::inner_product(float a[3], float b[3]){
	float buf = a[0]*b[0];
	buf += a[1]*b[1];
	buf += a[2]*b[2];
	return buf;
}
unsigned char CPUrender::trilinear(float pos[3]){//삼선형보간법
	int iX = (int)pos[0];
	int iY = (int)pos[1];
	int iZ = (int)pos[2];
	float fracX = pos[0] - iX;
	float fracY = pos[1] - iY;
	float fracZ = pos[2] - iZ;
	unsigned char data[8];

	for(int i = 0; i < 8; i++){
		int j = i;
		int x, y, z;
		x = y = z = 0;

		z = (j & 4) >> 2;
		y = (j & 2) >> 1;
		x = (j & 1);
		//데이터와 데이터외부의 애매한부분을 처리함
		if(0<=iX+x && iX+x<256 && 0<=iY+y && iY+y<256 && 0<=iZ+z && iZ+z<225)//안쪽이면
			data[i] = volume[(iZ+z)*volumeSize[0]*volumeSize[1] + (iY+y)*volumeSize[0]+iX+x];		
		else//밖이면
			data[i] = 0;
	}

	return (((data[0]*(1-fracX)+data[1]*fracX)*(1-fracY)+(data[2]*(1-fracX)+data[3]*fracX)*fracY)*(1-fracZ))+ (((data[4]*(1-fracX)+data[5]*fracX)*(1-fracY)+(data[6]*(1-fracX)+data[7]*fracX)*fracY)*fracZ);
}
void CPUrender::getNormal(float x, float y, float z, float N[3]){
	float buf[6][3] = {x+1, y, z,
		x-1, y, z,
		x, y+1, z,
		x, y-1, z,
		x, y, z+1,
		x, y, z-1};
	N[0] = (trilinear(buf[0]) - trilinear(buf[1]))/2.0;
	N[1] = (trilinear(buf[2]) - trilinear(buf[3]))/2.0;
	N[2] = (trilinear(buf[4]) - trilinear(buf[5]))/2.0;

	float len = vec_lenth(N);
	if(len != 0)//0으로 나눠지는걸 주의하자
		s_product(N, 1/vec_lenth(N), N); //단위벡터로 만들기
}
float CPUrender::sign(float a){
	if(a > 0)
		return 1.0f;
	if(a < 0)
		return -1.0f;
	return 0.0f;
}


bool CPUrender::IsIntersectRayBox1(float& startT, float& endT, float pos[3], int tx, int ty){
	float buf[3];
	float start[3];
	float dx[3], dy[3];
	float delta[3];
	float Max[3], Min[3];//x, y, z의 최대, 최소
	int j = 0;

	s_product(cross, tx-resolution/2, dx);//x계산
	s_product(u, ty-resolution/2, dy);//y계산
	vec_add(dx, dy, delta);//x+y = point
	vec_add(eye, delta, start);//start+eye = start <- 시작지점

	for(int i = 0; i < 3; i++){
		float a, b;
		if(validDir[i] == 1){
			a = (volumeSize[i] - start[i])/ dir[i];
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
	s_product(dir, startT, buf);
	vec_add(start, buf, pos);

	int iPos[3] = {(int)pos[0], (int)pos[1], (int)pos[2]};

	if(!(0<=iPos[0] && iPos[0]<volumeSize[0] && 0<=iPos[1] && iPos[1]<volumeSize[1] && 0<=iPos[2] && iPos[2]<volumeSize[2])){
		return false;
	}
	return true;
}
int CPUrender::EmptySpaceLeap1(float pos[3]){
	int dt = 0;
	int currentBox[3] = {(int)pos[0], (int)pos[1]/8, (int)pos[2]/8};
	int currentBoxId = currentBox[0]+ currentBox[1]*blockSize[0] + currentBox[2]*blockSize[0]*blockSize[1];

	if(emptyBlock[currentBoxId]){
		
		while(true){
			dt++;
			vec_add(pos, dir, pos);

			int forwardBox[3] = {(int)pos[0]/8, (int)pos[1]/8, (int)pos[2]/8};

			//새로운 박스에 도달하면 빈공간도약검사를 끝낸다.
			if(currentBox[0] != forwardBox[0] || currentBox[1] != forwardBox[1] || currentBox[2] != forwardBox[2])
				return dt;									
		}
	}	
	//비어있지않으면 알파블렌딩
	return dt;
}
float CPUrender::AlphaBlending1(float pos[3], float3& cAcc, const float aOld){
	unsigned char nowData = trilinear(pos);
	float nextPos[3] = {pos[0]+dir[0], pos[1]+dir[1], pos[2]+dir[2]};
	unsigned char nextData = trilinear(nextPos);

	float N[3];// 픽셀의 법선벡터
	getNormal(pos[0], pos[1], pos[2], N);//법선벡터를 찾는다.

	float NL = fabs(inner_product(N, L));//N과 L의 내적  - 절대값
	float NH = fabs(pow(inner_product(N, dir), 16));
	float light = 0.2f + 0.7f*NL + 0.1f*NH; 
	if(light > 1.0f)
		light = 1.0f;

	light *= 1.0f-aOld;
	float alpha = pit[nowData][nextData].w;
	cAcc.x += pit[nowData][nextData].x*light;
	cAcc.y += pit[nowData][nextData].y*light;
	cAcc.z += pit[nowData][nextData].z*light;
	
	return 1.0f-(1.0f-aOld) * (1.0f-alpha);//알파값 리턴
}
float3 CPUrender::RayTracing1(float start[3], const int startT, const int endT){
	float pos[3] = {start[0], start[1], start[2]};
	float aNew = 0.0f;
	float aOld = 0.0f;
	float3 cAcc = {0};
	
	for(int t = startT; t <= endT; t++){
		int dt = EmptySpaceLeap1(pos);

		//dt는 생략할 칸수 
		if(dt){//공간이 비어있다면			
			t+=dt-1;
			continue;
		}		

		aNew = AlphaBlending1(pos, cAcc, aOld);		
		//Early Ray Termination
		if(aNew > 0.99f)
			break;	

		aOld = aNew;
		
		vec_add(pos, dir, pos);
	}
	return cAcc;
}
void CPUrender::C_Parallel(){
	clock_t start, end;

	start = clock();
	for(int ty = 0; ty < resolution; ty++){
		for(int tx = 0; tx < resolution; tx++){
			const int locTexture = tx + ty*resolution;
			float pos[3];
			float startT, endT;

			if(!IsIntersectRayBox1(startT, endT, pos, tx, ty)){
				tex[locTexture*3] = 0;
				tex[locTexture*3 + 1] = 0;
				tex[locTexture*3 + 2] = 0;
				continue;//유효하지 않은 좌표면 다음진행
			}
			
			float3 cAcc = RayTracing1(pos, startT, endT);	

			tex[locTexture*3] = (unsigned char)(cAcc.x*255.0f);
			tex[locTexture*3 + 1] = (unsigned char)(cAcc.y*255.0f);
			tex[locTexture*3 + 2] = (unsigned char)(cAcc.z*255.0f);
		}
	}
	end = clock();
	printf("cpu Parallel rendering : %.3lf초\n",(end-start)/1000.0);
	
}

bool CPUrender::IsIntersectRayBox2(float& startT, float& endT, float pos[3], float rayDir[3], int tx, int ty){
	float buf[3];
	float f[3];
	float cameraCenter[3];
	float start[3];
	float dx[3], dy[3];
	float delta[3];
	float Max[3], Min[3];//x, y, z의 최대, 최소
	int j = 0;

	s_product(cross, tx-resolution*0.5f, dx);//x계산
	s_product(dx, 0.005f, dx);//x계산
	s_product(u, ty-resolution*0.5f, dy);//y계산
	s_product(dy, 0.005f, dy);
	vec_add(dx, dy, delta);//x+y = point

	//s_product(dir, 0.5f, f);
	vec_add(eye, dir, cameraCenter);
	vec_add(cameraCenter, delta, start);//start <- 시작지점
	vec_sub(start, eye, rayDir);//rayDir 픽셀마다의 진행방향
	s_product(rayDir, 1/vec_lenth(rayDir), rayDir);

	for(int i = 0; i < 3; i++){
		float a, b;
		if(validDir[i] == 1){
			a = (volumeSize[i]-1 - start[i])/ rayDir[i];
			b = (0.0f - start[i])/ rayDir[i];
			

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

	if(0<=start[0] && start[0]<volumeSize[0] && 0<=start[1] && start[1]<volumeSize[1] && 0<=start[2] && start[2]<volumeSize[2]){
		pos[0] = start[0];
		pos[1] = start[1];
		pos[2] = start[2];
		startT = 0;
		return true;
	}


	startT = Min[0];
	for(int i = 1; i < j; i++){//Min중 Max를 찾자. = startT가 된다.
		if(startT < Min[i])
			startT = Min[i];
	}
	startT += 0.001f;

	//광선과 데이터가 만나는 점을 찾아보자.
	s_product(rayDir, startT, buf);
	vec_add(start, buf, pos);

	int iPos[3] = {(int)pos[0], (int)pos[1], (int)pos[2]};

	if(!(0<=iPos[0] && iPos[0]<volumeSize[0] && 0<=iPos[1] && iPos[1]<volumeSize[1] && 0<=iPos[2] && iPos[2]<volumeSize[2])){
		return false;
	}
	return true;
}
int CPUrender::EmptySpaceLeap2(float pos[3], float rayDir[3]){
	int dt = 0;
	int currentBox[3] = {(int)pos[0], (int)pos[1]/8, (int)pos[2]/8};
	int currentBoxId = currentBox[0]+ currentBox[1]*blockSize[0] + currentBox[2]*blockSize[0]*blockSize[1];

	if(emptyBlock[currentBoxId]){
		
		while(true){
			dt++;
			vec_add(pos, rayDir, pos);

			int forwardBox[3] = {(int)pos[0]/8, (int)pos[1]/8, (int)pos[2]/8};

			//새로운 박스에 도달하면 빈공간도약검사를 끝낸다.
			if(currentBox[0] != forwardBox[0] || currentBox[1] != forwardBox[1] || currentBox[2] != forwardBox[2])
				return dt;									
		}
	}	
	//비어있지않으면 알파블렌딩
	return dt;
}
float CPUrender::AlphaBlending2(float pos[3], float rayDir[3], float3& cAcc, const float aOld){
	unsigned char nowData = trilinear(pos);
	float nextPos[3] = {pos[0]+rayDir[0], pos[1]+rayDir[1], pos[2]+rayDir[2]};
	unsigned char nextData = trilinear(nextPos);

	float N[3];// 픽셀의 법선벡터
	getNormal(pos[0], pos[1], pos[2], N);//법선벡터를 찾는다.

	float NL = fabs(inner_product(N, L));//N과 L의 내적  - 절대값
	float NH = fabs(pow(inner_product(N, dir), 16));
	float light = 0.2f + 0.7f*NL + 0.1f*NH; 
	if(light > 1.0f)
		light = 1.0f;

	light *= 1.0f-aOld;
	float alpha = pit[nowData][nextData].w;
	cAcc.x += pit[nowData][nextData].x*light;
	cAcc.y += pit[nowData][nextData].y*light;
	cAcc.z += pit[nowData][nextData].z*light;
	
	return 1.0f-(1.0f-aOld) * (1.0f-alpha);//알파값 리턴
}
float3 CPUrender::RayTracing2(float start[3], float rayDir[3], const int startT, const int endT){
	float pos[3] = {start[0], start[1], start[2]};
	float aNew = 0.0f;
	float aOld = 0.0f;
	float3 cAcc = {0};
	
	for(int t = startT; t <= endT; t++){
		int dt = EmptySpaceLeap2(pos, rayDir);

		//dt는 생략할 칸수 
		if(dt){//공간이 비어있다면			
			t+=dt-1;
			continue;
		}		

		aNew = AlphaBlending2(pos, rayDir, cAcc, aOld);		
		//Early Ray Termination
		if(aNew > 0.99f)
			break;	

		aOld = aNew;
		
		vec_add(pos, rayDir, pos);
	}
	return cAcc;
}
void CPUrender::C_Perspective(){
	clock_t start, end;

	start = clock();
	for(int ty = 0; ty < resolution; ty++){
		for(int tx = 0; tx < resolution; tx++){
			const int locTexture = tx + ty*resolution;
			float pos[3];
			float rayDir[3];
			float startT, endT;

			if(!IsIntersectRayBox2(startT, endT, pos, rayDir, tx, ty)){
				tex[locTexture*3] = 0;
				tex[locTexture*3 + 1] = 0;
				tex[locTexture*3 + 2] = 0;
				continue;//유효하지 않은 좌표면 다음진행
			}
			
			float3 cAcc = RayTracing2(pos, rayDir, startT, endT);	

			tex[locTexture*3] = (unsigned char)(cAcc.x*255.0f);
			tex[locTexture*3 + 1] = (unsigned char)(cAcc.y*255.0f);
			tex[locTexture*3 + 2] = (unsigned char)(cAcc.z*255.0f);
		}
	}
	end = clock();
	printf("cpu Perspectivve rendering : %.3lf초\n",(end-start)/1000.0);
}



void CPUrender::InitColor(){
	unsigned char transparentTable[256];
	
	int buf=0;
	for(int i = 0; i < 256; i++){
		if(alphaTable[i] == 0){
			transparentTable[i] = 0;
			buf++;
		}
		else		
			transparentTable[i] = 1;
	}
	//버그잡기
	if(buf != 256)
		transparentTable[205] = 1;
	
	int aSAT[257]; // summed area table
	int *pSAT = &(aSAT[1]);  //pSAT[-1] == aSAT[0];
	pSAT[-1] = 0;
	for(int i=0; i<256; i++) {
		pSAT[i] = transparentTable[i] + pSAT[i-1];
	}
	unsigned char bx, by, bz;
	for(bz = 0; bz < blockSize[2]; bz++){
		for(by = 0; by < blockSize[1]; by++){			
			for(bx = 0; bx < blockSize[0]; bx++){
				int index = bz*blockSize[1]*blockSize[0] + by*blockSize[0] + bx;
				int m = emptyBlockMin[index];
				int M = emptyBlockMax[index];

				emptyBlock[index] = (pSAT[M] == pSAT[m-1]) ? true : false;
			}
		}
	}
	InitPreIntegration();
}
void CPUrender::InitMinMaxEmptyBlock(){
	unsigned char bx, by, bz;
	int vx, vy, vz;
	unsigned char data;
	
	for(bz = 0; bz < blockSize[2]; bz++) {
		for(by = 0; by < blockSize[1]; by++){
			for(bx = 0; bx < blockSize[0]; bx++) {

				//한 덩어리의 최대값과 최소값을 찾는다.
				for(vz = bz*8; vz <= bz*8 + 8; vz++){
					if(vz >= blockSize[2]-1)
						break;
					for(vy = by*8; vy <= by*8 + 8; vy++){  
						for(vx = bx*8; vx <= bx*8 + 8; vx++){         
							data = volume[vz*volumeSize[0]*volumeSize[1] + vy*volumeSize[0]+vx];
							
							emptyBlockMax[bz*blockSize[1]*blockSize[0] + by*blockSize[0] + bx] 
							= MAX(emptyBlockMax[bz*blockSize[1]*blockSize[0] + by*blockSize[0] + bx], data);
							emptyBlockMin[bz*blockSize[1]*blockSize[0] + by*blockSize[0] + bx] 
							= MIN(emptyBlockMin[bz*blockSize[1]*blockSize[0] + by*blockSize[0] + bx], data);

						}
					}
				}
				//한 덩어리 검사 끝
			}
		}
	}
}

void CPUrender::InitPreIntegration(){
	for(int i = 0; i < 256; i++){
		if(i == 255){
			for(int j = 0; j < 256; j++){
				float A = alphaTable[j];

				pit[j][j].w = A;
				pit[j][j].x = colorTable[j].x * A;
				pit[j][j].y = colorTable[j].y * A;
				pit[j][j].z = colorTable[j].z * A;
			}
		}
		else{
			//superSampling Table
			int k = 255 - i;//간격
			float samplingTable[256];//K번 alpha-correction된 alphaTable
			for(int j = 0; j < 256; j++){
				float A = alphaTable[j];//최소값+j번째의 alpha값을 찾는다. s == e면 진행할필요없음
				A = 1 - powf(1 - A, 1.0/k);
				samplingTable[j] = A;
			}

			//preIntegration Table
			int s = 0;
			int e = 255-i;
			while(s <= i){
				float A = 0, aOld = 0, aNew = 0;
				float3 cAcc = {0};
				//정사각형의 대각선 /을 기준으로 왼쪽상단
				for(int j = s; j < e; j++){
					A = samplingTable[j];
					aNew = 1 - (1 - aOld)*(1 - A);
					cAcc.x += (1 - aOld)*colorTable[j].x*A;
					cAcc.y += (1 - aOld)*colorTable[j].y*A;
					cAcc.z += (1 - aOld)*colorTable[j].z*A;
					if(aNew > 0.99)
						break;
					aOld = aNew;
				}
				pit[s][e].w = aNew;
				pit[s][e].x = cAcc.x;
				pit[s][e].y = cAcc.y;
				pit[s][e].z = cAcc.z;


				//정사각형의 대각선 /을 기준으로 오른쪽하단
				aOld = 0, aNew = 0;
				cAcc.x = cAcc.y = cAcc.z = 0;
				for(int j = e; j > s; j--){
					A = samplingTable[j];
					aNew = 1 - (1 - aOld)*(1 - A);
					cAcc.x += (1 - aOld)*colorTable[j].x*A;
					cAcc.y += (1 - aOld)*colorTable[j].y*A;
					cAcc.z += (1 - aOld)*colorTable[j].z*A;
					if(aNew > 0.99)
						break;
					aOld = aNew;
				}
				pit[e][s].w = aNew;
				pit[e][s].x = cAcc.x;
				pit[e][s].y = cAcc.y;
				pit[e][s].z = cAcc.z;

				s++;e++;
			}

		}
	}
}

void CPUrender::InitCpuConst(){
	vec_sub(at, eye, dir); //dir 벡터 생성
	s_product(dir, 1.0f/vec_lenth(dir), dir); //dir을 정규화

	cross_product(up, dir, cross);//cross벡터 생성 
	s_product(cross, (256.0f/resolution)*zoom/vec_lenth(cross), cross);//cross벡터 정규화 <- 시점의 x좌표

	cross_product(dir, cross, u);//u벡터 생성 
	s_product(u, (256.0f/resolution)*zoom/vec_lenth(u), u);//u벡터 정규화 <- 시점의 y좌표

	if(dir[0] != 0)//x방향이 0이 아니면
		validDir[0] = 1;
	if(dir[1] != 0)//y방향이 0이 아니면
		validDir[1] = 1;
	if(dir[2] != 0)//z방향이 0이 아니면
		validDir[2] = 1;
}
void CPUrender::InitVolume(unsigned char* Volume, int size[3]){
	volume = Volume;
	volumeSize[0] = size[0];
	volumeSize[1] = size[1];
	volumeSize[2] = size[2];
	at[0] = size[0]/2;
	at[1] = size[1]/2;
	at[2] = size[2]/2;

	blockSize[0] = volumeSize[0]/8;
	blockSize[1] = volumeSize[1]/8;
	blockSize[2] = volumeSize[2]/8;
	if(volumeSize[0]%8)
		blockSize[0]+=1;
	if(volumeSize[1]%8)
		blockSize[1]+=1;
	if(volumeSize[2]%8)
		blockSize[2]+=1;

	InitMinMaxEmptyBlock();
}
void CPUrender::InitAlphaTable(float* AlphaTable){
	alphaTable = AlphaTable;
}
void CPUrender::InitColorTable(float3* ColorTable){
	colorTable = ColorTable;
}
void CPUrender::ChangeView(bool perspective){
	PerspectiveView = perspective;
}
void CPUrender::ChangeResolution(int n){
	resolution = n;
	InitCpuConst();
}
void CPUrender::ForwardEye(bool forward){
	if(forward){
		if(PerspectiveView){
			float buf[3];
			s_product(dir, 20, buf);
			vec_add(eye, buf, eye);
		}
		else
			zoom /= 1.1f;
	}
	else{
		if(PerspectiveView){
			float buf[3];
			s_product(dir, 20, buf);
			vec_sub(eye, buf, eye);
		}			
		else
			zoom *= 1.1f;
	}

	printf("eye (%.3f, %.3f, %.3f)\n", eye[0], eye[1], eye[2]);
	printf("dir (%.3f, %.3f, %.3f)\n", dir[0], dir[1], dir[2]);
	InitCpuConst();
}
void CPUrender::MouseRotateEye(int x, int y){
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

	InitCpuConst();
}

void CPUrender::Rendering(){

	if(PerspectiveView)
		C_Perspective();
	else
		C_Parallel();		
}
void CPUrender::DrawTexture(){
	glClear(GL_COLOR_BUFFER_BIT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexImage2D(GL_TEXTURE_2D, 0, 3, resolution, resolution, 0, GL_RGB, GL_UNSIGNED_BYTE, (void *)tex);
	glEnable(GL_TEXTURE_2D);
	glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_DECAL);
	glBegin(GL_QUADS);
		glTexCoord2f(0.0, 0.0); glVertex2f(-1.0, -1.0);
		glTexCoord2f(0.0, 1.0); glVertex2f(-1.0, 1.0);
		glTexCoord2f(1.0, 1.0); glVertex2f(1.0, 1.0);
		glTexCoord2f(1.0, 0.0); glVertex2f(1.0, -1.0);
	glEnd();
}