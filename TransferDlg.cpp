// TransferDlg.cpp : 구현 파일입니다.


#include "stdafx.h"
#include "EyeBody.h"
#include "TransferDlg.h"
#include "afxdialogex.h"
#include "vector_types.h"




// CTransferDlg 대화 상자입니다.

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


// CTransferDlg 메시지 처리기입니다.


HBRUSH CTransferDlg::OnCtlColor(CDC* pDC, CWnd* pWnd, UINT nCtlColor)
{
	HBRUSH hbr = CDialog::OnCtlColor(pDC, pWnd, nCtlColor);

	// TODO:  여기서 DC의 특성을 변경합니다.


	// TODO:  기본값이 적당하지 않으면 다른 브러시를 반환합니다.
	return hbr;
}


BOOL CTransferDlg::OnInitDialog()
{
	CDialog::OnInitDialog();
	AllocConsole();//콘솔
	pen_flag = false;

	CWnd *pWnd1;
	pWnd1 = (CWnd*)GetDlgItem(IDC_PIC1); 
	pWnd1->MoveWindow(20, 18, 512, 302 );//다이얼로그의 크기와 위치값 조정을 위한 함수.
	
	// TODO:  여기에 추가 초기화 작업을 추가합니다.
	m_ctlPic1.GetClientRect(&rect_user);
	rect_user.NormalizeRect();
	m_ctlPic1.ClientToScreen(&rect_user);
	ScreenToClient(&rect_user); 

	CMainFrame* pFrame = (CMainFrame*)AfxGetMainWnd();  // 프레임 윈도우 포인터 구하고...
	CEyeBodyView* pView = (CEyeBodyView*) pFrame->GetActiveView(); // 활성화된 뷰의 포인터 구한다.
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
	// 예외: OCX 속성 페이지는 FALSE를 반환해야 합니다.
}


void CTransferDlg::OnPaint()
{
	CPaintDC dc(this); // device context for painting
	// TODO: 여기에 메시지 처리기 코드를 추가합니다.
	// 그리기 메시지에 대해서는 CDialog::OnPaint()을(를) 호출하지 마십시오.
	
	//배경색 설정 시작
	CBrush brush;
	brush.CreateSolidBrush(RGB(255, 255, 255)); 
	dc.FillRect(rect_user,&brush); 
	//배경색 설정 완료

	//중심선 그리기 시작
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
	//중심선 그리기 완료

	//x축 격자 시작
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
	//x축 격자 완료
	
	//transfer그래프 그리기 시작
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
	//transfer그래프 그리기 완료
}


void CTransferDlg::OnLButtonDown(UINT nFlags, CPoint point)
{
	// TODO: 여기에 메시지 처리기 코드를 추가 및/또는 기본값을 호출합니다.
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
	// TODO: 여기에 메시지 처리기 코드를 추가 및/또는 기본값을 호출합니다.

	pen_flag = false;		
	//InvalidateRect(&rect_user, TRUE);
	for(int i = 0; i < 256; i++)
		alphaTable[i] = ((float)transfer[i*2].y+transfer[i*2+1].y)/600;
	if(GPUrendering)
		gpuRender->InitColor();
	else
		cpuRender->InitColor();
	CMainFrame* pFrame = (CMainFrame*)AfxGetMainWnd();  // 프레임 윈도우 포인터 구하고...
	CEyeBodyView* pView = (CEyeBodyView*) pFrame->GetActiveView(); // 활성화된 뷰의 포인터 구한다.
	pView->DrawGLScene();

	CDialog::OnLButtonUp(nFlags, point);
}


void CTransferDlg::OnMouseMove(UINT nFlags, CPoint point)
{
	// TODO: 여기에 메시지 처리기 코드를 추가 및/또는 기본값을 호출합니다.
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
	// TODO: 여기에 컨트롤 알림 처리기 코드를 추가합니다.
	for(int i = 0; i < 512; i++){
		transfer[i].y = 0;
		if(i<256)
			alphaTable[i] = 0;
	}
	if(GPUrendering)
		gpuRender->InitColor();
	else
		cpuRender->InitColor();

	CMainFrame* pFrame = (CMainFrame*)AfxGetMainWnd();  // 프레임 윈도우 포인터 구하고...
	CEyeBodyView* pView = (CEyeBodyView*) pFrame->GetActiveView(); // 활성화된 뷰의 포인터 구한다.
	pView->DrawGLScene();

	InvalidateRect(&rect_user, FALSE);
}


void CTransferDlg::OnEnChangeEdit2()
{
	// TODO:  RICHEDIT 컨트롤인 경우, 이 컨트롤은
	// CDialog::OnInitDialog() 함수를 재지정 
	//하고 마스크에 OR 연산하여 설정된 ENM_CHANGE 플래그를 지정하여 CRichEditCtrl().SetEventMask()를 호출하지 않으면
	// 이 알림 메시지를 보내지 않습니다.

	// TODO:  여기에 컨트롤 알림 처리기 코드를 추가합니다.
}


void CTransferDlg::OnBnClickedColorBtn()
{
	// TODO: 여기에 컨트롤 알림 처리기 코드를 추가합니다.
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

	CMainFrame* pFrame = (CMainFrame*)AfxGetMainWnd();  // 프레임 윈도우 포인터 구하고...
	CEyeBodyView* pView = (CEyeBodyView*) pFrame->GetActiveView(); // 활성화된 뷰의 포인터 구한다.
	pView->DrawGLScene();

	InvalidateRect(&rect_user, FALSE);
}
