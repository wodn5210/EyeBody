#pragma once
#include <cuda.h>
#include <stdio.h>

#include <gl/glew.h>
#include <gl/freeglut.h>
#include <cuda_gl_interop.h>

class GPUrender{
private :
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

	unsigned char* gEmptyBlockMax;
	unsigned char* gEmptyBlockMin;
	float4* gPIT;

public:
	GPUrender();
	void InitVolume(unsigned char* Volume, int size[3]);
	void InitAlphaTable(float* AlphaTable);
	void InitColorTable(float3* ColorTable);
	void ChangeView(bool perspective);
	void ChangeResolution(int n);
	void ForwardEye(bool forward);
	void MouseRotateEye(int x, int y);

	void Rendering();
	void DrawTexture();

	void InitColor();
	void InitGpuConst();
	void EyeBodyCancel();
	void InitPixelBuffer();
};