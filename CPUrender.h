#pragma once
#include <stdio.h>
#include <GL/glut.h>
#include <GL/gl.h>
#include <GL/glu.h>
#include "vector_types.h"

class CPUrender{
private:
	unsigned char* volume;
	float* alphaTable;
	float3* colorTable;

	int volumeSize[3];
	int blockSize[3];
	bool PerspectiveView;
	float eye[3];
	float dir[3];
	float L[3];//±§ø¯ ∫§≈Õ
	float cross[3];
	float u[3];
	float at[3];
	float up[3];
	int validDir[3];//¿Ø»øπÊ«‚∞À√‚
	float zoom;
	int resolution;

	float4 pit[256][256];
	unsigned char emptyBlockMax[40*40*40];
	unsigned char emptyBlockMin[40*40*40];
	bool emptyBlock[40*40*40];
	unsigned char tex[512*512*3];

public:
	CPUrender();

	void vec_add(float a[3], float b[3], float c[3]);
	void vec_sub(float a[3], float b[3], float c[3]);
	void s_product(float a[3], float size, float b[3]);
	void cross_product(float a[3], float b[3], float c[3]);
	float vec_lenth(float a[3]);
	float inner_product(float a[3], float b[3]);
	unsigned char trilinear(float pos[3]);
	void getNormal(float x, float y, float z, float N[3]);
	float sign(float a);
	

	bool IsIntersectRayBox1(float& startT, float& endT, float pos[3], int tx, int ty);
	int EmptySpaceLeap1(float pos[3]);
	float AlphaBlending1(float pos[3], float3& cAcc, const float aOld);
	float3 RayTracing1(float start[3], const int startT, const int endT);
	void C_Parallel();

	bool IsIntersectRayBox2(float& startT, float& endT, float pos[3], float dir[3], int tx, int ty);
	int EmptySpaceLeap2(float pos[3], float rayDir[3]);
	float AlphaBlending2(float pos[3], float rayDir[3], float3& cAcc, const float aOld);
	float3 RayTracing2(float start[3], float rayDir[3], const int startT, const int endT);
	void C_Perspective();

	void InitColor();
	void InitMinMaxEmptyBlock();
	void InitPreIntegration();
	void InitCpuConst();
	void InitVolume(unsigned char* Volume, int size[3]);
	void InitAlphaTable(float* AlphaTable);
	void InitColorTable(float3* ColorTable);
	void ChangeView(bool perspective);
	void ChangeResolution(int n);
	void ForwardEye(bool forward);
	void MouseRotateEye(int x, int y);

	void Rendering();
	void DrawTexture();
};