// TransferDlg.cpp : ���� �����Դϴ�.


#include "stdafx.h"
#include "EyeBody.h"
#include "TransferDlg.h"
#include "afxdialogex.h"
#include "vector_types.h"




// CTransferDlg ��ȭ �����Դϴ�.

IMPLEMENT_DYNAMIC(CTransferDlg, CDialog)

CTransferDlg::CTransferDlg(CWnd* pParent /*=NULL*/)
	: CDialog(CTransferDlg::IDD, pParent)
{

}

CTransferDlg::~CTransferDlg()
{
}

void CTransferDlg::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	DDX_Control(pDX, IDC_PIC1, m_ctlPic1);
}


BEGIN_MESSAGE_MAP(CTransferDlg, CDialog)
	ON_WM_CTLCOLOR()
	ON_WM_PAINT()
	ON_WM_LBUTTONDOWN()
	ON_WM_LBUTTONUP()
	ON_WM_MOUSEMOVE()
	ON_BN_CLICKED(IDC_BUTTON1, &CTransferDlg::OnBnClickedButton)
	ON_EN_CHANGE(IDC_EDIT2, &CTransferDlg::OnEnChangeEdit2)
	ON_BN_CLICKED(IDC_BUTTON2, &CTransferDlg::OnBnClickedColorBtn)
END_MESSAGE_MAP()


// CTransferDlg �޽��� ó�����Դϴ�.


HBRUSH CTransferDlg::OnCtlColor(CDC* pDC, CWnd* pWnd, UINT nCtlColor)
{
	HBRUSH hbr = CDialog::OnCtlColor(pDC, pWnd, nCtlColor);

	// TODO:  ���⼭ DC�� Ư���� �����մϴ�.


	// TODO:  �⺻���� �������� ������ �ٸ� �귯�ø� ��ȯ�մϴ�.
	return hbr;
}


BOOL CTransferDlg::OnInitDialog()
{
	CDialog::OnInitDialog();
	AllocConsole();//�ܼ�
	pen_flag = false;

	CWnd *pWnd1;
	pWnd1 = (CWnd*)GetDlgItem(IDC_PIC1); 
	pWnd1->MoveWindow(20, 18, 512, 302 );//���̾�α��� ũ��� ��ġ�� ������ ���� �Լ�.
	
	// TODO:  ���⿡ �߰� �ʱ�ȭ �۾��� �߰��մϴ�.
	m_ctlPic1.GetClientRect(&rect_user);
	rect_user.NormalizeRect();
	m_ctlPic1.ClientToScreen(&rect_user);
	ScreenToClient(&rect_user); 

	CMainFrame* pFrame = (CMainFrame*)AfxGetMainWnd();  // ������ ������ ������ ���ϰ�...
	CEyeBodyView* pView = (CEyeBodyView*) pFrame->GetActiveView(); // Ȱ��ȭ�� ���� ������ ���Ѵ�.
	colorTable = pView->colorTable;
	alphaTable = pView->alphaTable;
	transfer = pView->transfer;
	GPUrendering = pView->GPUrendering;
	if(GPUrendering){
		gpuRender = &(pView->gpuRender);
	}
	else{
		cpuRender = &(pView->cpuRender);
	}

	for(int i = 0; i < 512; i++){
		transfer[i].x =rect_user.left + i;
	}

	return TRUE;  // return TRUE unless you set the focus to a control
	// ����: OCX �Ӽ� �������� FALSE�� ��ȯ�ؾ� �մϴ�.
}


void CTransferDlg::OnPaint()
{
	CPaintDC dc(this); // device context for painting
	// TODO: ���⿡ �޽��� ó���� �ڵ带 �߰��մϴ�.
	// �׸��� �޽����� ���ؼ��� CDialog::OnPaint()��(��) ȣ������ ���ʽÿ�.
	
	//���� ���� ����
	CBrush brush;
	brush.CreateSolidBrush(RGB(255, 255, 255)); 
	dc.FillRect(rect_user,&brush); 
	//���� ���� �Ϸ�

	//�߽ɼ� �׸��� ����
	CPen* pOldpen;
	CPen pen3;      
	int k;        
	pen3.CreatePen(PS_DOT,1,RGB(100,100,100));   
	pOldpen=dc.SelectObject(&pen3);    

	CString y_val;      
	CRect y_pos;      
	k=rect_user.bottom-rect_user.Height()/2; 
	y_pos.top=k;      
	y_pos.bottom=k+20;     
	y_pos.left= rect_user.left-40;     
	y_pos.right= rect_user.left;     
     
	dc.MoveTo(rect_user.left,k);     
	dc.LineTo(rect_user.right,k);     
	y_val.Format("%.1f", 0.5);     
	dc.DrawText(y_val,y_pos,DT_RIGHT);
	//�߽ɼ� �׸��� �Ϸ�

	//x�� ���� ����
	CString x_val;
	CRect x_pos;
	x_pos.top = rect_user.bottom;
	x_pos.bottom = x_pos.top + 20;
	for(int j = 1; j < 9; j++){
		k = rect_user.left+(rect_user.Width()*j)/8;
		x_pos.left = k-20;
		x_pos.right = x_pos.left+40;
		x_val.Format("%d", j*32);
		dc.DrawText(x_val, x_pos, DT_CENTER);
		if(j != 8){
			dc.MoveTo(k, rect_user.top);
			dc.LineTo(k, rect_user.bottom);	
		}
	}
	//x�� ���� �Ϸ�
	
	//transfer�׷��� �׸��� ����
	CPen pen2;
	pen2.CreatePen(PS_SOLID,1,RGB(0,0,0));	
	pOldpen = dc.SelectObject(&pen2);

	
	for(int i = 0; i < 512-1; i++)
	{
		if(!(transfer[i].y == 0 && transfer[i+1].y == 0)){
			dc.MoveTo(transfer[i].x, rect_user.bottom - transfer[i].y-1);
			dc.LineTo(transfer[i+1].x, rect_user.bottom - transfer[i+1].y-1);		
		}
		//dc.SetPixelV(transfer[i], RGB(255,0,0));
	}
	//transfer�׷��� �׸��� �Ϸ�
}


void CTransferDlg::OnLButtonDown(UINT nFlags, CPoint point)
{
	// TODO: ���⿡ �޽��� ó���� �ڵ带 �߰� ��/�Ǵ� �⺻���� ȣ���մϴ�.
	if((20 <= point.x && point.x < 532) && (20 <= point.y && point.y < 320)){
		pen_flag = true;
		m_MouseOld = point;
		CString str;
		str.Format("%d", (point.x - 20)/2);
		SetDlgItemText(IDC_EDIT1, str);
	}
	CDialog::OnLButtonDown(nFlags, point);
}


void CTransferDlg::OnLButtonUp(UINT nFlags, CPoint point)
{
	// TODO: ���⿡ �޽��� ó���� �ڵ带 �߰� ��/�Ǵ� �⺻���� ȣ���մϴ�.

	pen_flag = false;		
	//InvalidateRect(&rect_user, TRUE);
	for(int i = 0; i < 256; i++)
		alphaTable[i] = ((float)transfer[i*2].y+transfer[i*2+1].y)/600;
	if(GPUrendering)
		gpuRender->InitColor();
	else
		cpuRender->InitColor();
	CMainFrame* pFrame = (CMainFrame*)AfxGetMainWnd();  // ������ ������ ������ ���ϰ�...
	CEyeBodyView* pView = (CEyeBodyView*) pFrame->GetActiveView(); // Ȱ��ȭ�� ���� ������ ���Ѵ�.
	pView->DrawGLScene();

	CDialog::OnLButtonUp(nFlags, point);
}


void CTransferDlg::OnMouseMove(UINT nFlags, CPoint point)
{
	// TODO: ���⿡ �޽��� ó���� �ڵ带 �߰� ��/�Ǵ� �⺻���� ȣ���մϴ�.
	if((20 <= point.x && point.x < 532) && (20 <= point.y && point.y < 320) && pen_flag){
		CClientDC obj(this);
		obj.MoveTo(m_MouseOld);
		obj.LineTo(point);

		CString str;
		str.Format("%d", (point.x - 20)/2);
		SetDlgItemText(IDC_EDIT2, str);

		for(int i = m_MouseOld.x - 20; i <  point.x - 20; i++)
			transfer[i].y =  rect_user.bottom - point.y;
				
		m_MouseOld = point;
	
		InvalidateRect(&rect_user, FALSE);
	}
	CDialog::OnMouseMove(nFlags, point);
}




void CTransferDlg::OnBnClickedButton()
{
	// TODO: ���⿡ ��Ʈ�� �˸� ó���� �ڵ带 �߰��մϴ�.
	for(int i = 0; i < 512; i++){
		transfer[i].y = 0;
		if(i<256)
			alphaTable[i] = 0;
	}
	if(GPUrendering)
		gpuRender->InitColor();
	else
		cpuRender->InitColor();

	CMainFrame* pFrame = (CMainFrame*)AfxGetMainWnd();  // ������ ������ ������ ���ϰ�...
	CEyeBodyView* pView = (CEyeBodyView*) pFrame->GetActiveView(); // Ȱ��ȭ�� ���� ������ ���Ѵ�.
	pView->DrawGLScene();

	InvalidateRect(&rect_user, FALSE);
}


void CTransferDlg::OnEnChangeEdit2()
{
	// TODO:  RICHEDIT ��Ʈ���� ���, �� ��Ʈ����
	// CDialog::OnInitDialog() �Լ��� ������ 
	//�ϰ� ����ũ�� OR �����Ͽ� ������ ENM_CHANGE �÷��׸� �����Ͽ� CRichEditCtrl().SetEventMask()�� ȣ������ ������
	// �� �˸� �޽����� ������ �ʽ��ϴ�.

	// TODO:  ���⿡ ��Ʈ�� �˸� ó���� �ڵ带 �߰��մϴ�.
}


void CTransferDlg::OnBnClickedColorBtn()
{
	// TODO: ���⿡ ��Ʈ�� �˸� ó���� �ڵ带 �߰��մϴ�.
	CColorDialog colorDlg;
    colorDlg.DoModal();
	COLORREF buf = colorDlg.GetColor();

	CString str;
	GetDlgItemText(IDC_EDIT1, str);
	int start = _ttoi(str);
	GetDlgItemText(IDC_EDIT2, str);
	int end = _ttoi(str);
	if(end < start){
		int temp= start;
		start = end;
		end = temp;
	}
	for(int i = start-1; i <= end; i++){
		if( i < 0)
			continue;
		colorTable[i].x = GetRValue(buf)/255.0f;
		colorTable[i].y = GetGValue(buf)/255.0f;
		colorTable[i].z = GetBValue(buf)/255.0f;
	}
	if(GPUrendering)
		gpuRender->InitColor();
	else
		cpuRender->InitColor();

	CMainFrame* pFrame = (CMainFrame*)AfxGetMainWnd();  // ������ ������ ������ ���ϰ�...
	CEyeBodyView* pView = (CEyeBodyView*) pFrame->GetActiveView(); // Ȱ��ȭ�� ���� ������ ���Ѵ�.
	pView->DrawGLScene();

	InvalidateRect(&rect_user, FALSE);
}
