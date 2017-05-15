#pragma once
#include "afxwin.h"
#include "MainFrm.h"  // 최상위 프레임 윈도우 참조
#include "EyeBodyDoc.h"  // 다큐먼트 헤더
#include "EyeBodyView.h" // 뷰 헤더
#include "vector_types.h"
#include "GPUrender.cuh"

// CTransferDlg 대화 상자입니다.

class CTransferDlg : public CDialog
{
	DECLARE_DYNAMIC(CTransferDlg)
public:
	CTransferDlg(CWnd* pParent = NULL);  // 표준 생성자입니다.
	CRect rect_user;
	CPoint m_MouseOld;
	virtual ~CTransferDlg();
	bool pen_flag;
	bool GPUrendering;
	float* alphaTable;
	float3* colorTable;
	CPoint* transfer;
	GPUrender* gpuRender;
	CPUrender* cpuRender;

// 대화 상자 데이터입니다.
	enum { IDD = IDD_TRANSFERDLG };

protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV 지원입니다.

	DECLARE_MESSAGE_MAP()
public:
	CStatic m_ctlPic1;
	afx_msg HBRUSH OnCtlColor(CDC* pDC, CWnd* pWnd, UINT nCtlColor);
	virtual BOOL OnInitDialog();
	afx_msg void OnPaint();
	afx_msg void OnLButtonDown(UINT nFlags, CPoint point);
	afx_msg void OnLButtonUp(UINT nFlags, CPoint point);
	afx_msg void OnMouseMove(UINT nFlags, CPoint point);


	afx_msg void OnBnClickedButton();
	afx_msg void OnEnChangeEdit2();
	afx_msg void OnBnClickedColorBtn();
};
