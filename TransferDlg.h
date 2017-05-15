#pragma once
#include "afxwin.h"
#include "MainFrm.h"  // �ֻ��� ������ ������ ����
#include "EyeBodyDoc.h"  // ��ť��Ʈ ���
#include "EyeBodyView.h" // �� ���
#include "vector_types.h"
#include "GPUrender.cuh"

// CTransferDlg ��ȭ �����Դϴ�.

class CTransferDlg : public CDialog
{
	DECLARE_DYNAMIC(CTransferDlg)
public:
	CTransferDlg(CWnd* pParent = NULL);  // ǥ�� �������Դϴ�.
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

// ��ȭ ���� �������Դϴ�.
	enum { IDD = IDD_TRANSFERDLG };

protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV �����Դϴ�.

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
