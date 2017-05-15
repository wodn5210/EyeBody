
// EyeBodyView.h : CEyeBodyView 클래스의 인터페이스
//

#pragma once
#include "vector_types.h"
#include "GPUrender.cuh"
#include "CPUrender.h"

class CEyeBodyView : public CView
{
protected: // serialization에서만 만들어집니다.
	CEyeBodyView();
	DECLARE_DYNCREATE(CEyeBodyView)

// 특성입니다.
public:
	CEyeBodyDoc* GetDocument() const;

// 작업입니다.
public:
	HDC		m_hDC; 			// GDI Device Context
	HGLRC	m_hglRC;		// Rendering Context
	CPoint beforePoint;
	bool LClick;
	int viewWidth, viewHeight;
	bool m_Check;
	bool GPUrendering;
	int volumeSize[3];

	//볼륨크기 변경 어떻게?
	unsigned char volume[225][256][256];
	float alphaTable[256];
	float3 colorTable[256];
	CPoint transfer[512];
	GPUrender gpuRender;
	CPUrender cpuRender;

// 재정의입니다.
public:
	virtual void OnDraw(CDC* pDC);  // 이 뷰를 그리기 위해 재정의되었습니다.
	virtual BOOL PreCreateWindow(CREATESTRUCT& cs);
protected:
	virtual BOOL OnPreparePrinting(CPrintInfo* pInfo);
	virtual void OnBeginPrinting(CDC* pDC, CPrintInfo* pInfo);
	virtual void OnEndPrinting(CDC* pDC, CPrintInfo* pInfo);

// 구현입니다.
public:
	virtual ~CEyeBodyView();
#ifdef _DEBUG
	virtual void AssertValid() const;
	virtual void Dump(CDumpContext& dc) const;
#endif

protected:

// 생성된 메시지 맵 함수
protected:
	afx_msg void OnFilePrintPreview();
	afx_msg void OnRButtonUp(UINT nFlags, CPoint point);
	afx_msg void OnContextMenu(CWnd* pWnd, CPoint point);
	DECLARE_MESSAGE_MAP()
public:
	BOOL SetPixelformat(HDC hdc);
	afx_msg int OnCreate(LPCREATESTRUCT lpCreateStruct);
	afx_msg void OnDestroy();
	void InitGL(void);
	afx_msg void OnSize(UINT nType, int cx, int cy);
	void ReSizeGLScene(GLsizei width, GLsizei height);
	void DrawGLScene(void);
	afx_msg void OnLButtonDown(UINT nFlags, CPoint point);
	afx_msg void OnChangeTransfer();
	afx_msg void OnMouseMove(UINT nFlags, CPoint point);
	afx_msg void OnLButtonUp(UINT nFlags, CPoint point);
//	afx_msg void OnKeyDown(UINT nChar, UINT nRepCnt, UINT nFlags);
	afx_msg BOOL OnMouseWheel(UINT nFlags, short zDelta, CPoint pt);
	afx_msg void OnResol256();
	afx_msg void OnResol512();
	afx_msg void OnViewPararrel();
	afx_msg void OnViewPerspective();
	afx_msg void OnProcessorGpu();
	afx_msg void OnProcessorCpu();
};

#ifndef _DEBUG  // EyeBodyView.cpp의 디버그 버전
inline CEyeBodyDoc* CEyeBodyView::GetDocument() const
   { return reinterpret_cast<CEyeBodyDoc*>(m_pDocument); }
#endif

