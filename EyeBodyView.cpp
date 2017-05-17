
// EyeBodyView.cpp : CEyeBodyView 클래스의 구현
//
#include "stdafx.h"
// SHARED_HANDLERS는 미리 보기, 축소판 그림 및 검색 필터 처리기를 구현하는 ATL 프로젝트에서 정의할 수 있으며
// 해당 프로젝트와 문서 코드를 공유하도록 해 줍니다.
#ifndef SHARED_HANDLERS
#include "EyeBody.h"
#endif

#include "EyeBodyDoc.h"
#include "EyeBodyView.h"
#include "TransferDlg.h"
#include "vector_types.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#endif

// CEyeBodyView

IMPLEMENT_DYNCREATE(CEyeBodyView, CView)

BEGIN_MESSAGE_MAP(CEyeBodyView, CView)
	// 표준 인쇄 명령입니다.
	ON_COMMAND(ID_FILE_PRINT, &CView::OnFilePrint)
	ON_COMMAND(ID_FILE_PRINT_DIRECT, &CView::OnFilePrint)
	ON_COMMAND(ID_FILE_PRINT_PREVIEW, &CEyeBodyView::OnFilePrintPreview)
	ON_WM_CONTEXTMENU()
	ON_WM_RBUTTONUP()
	ON_WM_CREATE()
	ON_WM_DESTROY()
	ON_WM_SIZE()
	ON_WM_LBUTTONDOWN()
	ON_COMMAND(ID_Change_Transfer, &CEyeBodyView::OnChangeTransfer)
	ON_WM_MOUSEMOVE()
	ON_WM_LBUTTONUP()
//	ON_WM_KEYDOWN()
ON_WM_MOUSEWHEEL()
ON_COMMAND(ID_Resol_256, &CEyeBodyView::OnResol256)
ON_COMMAND(ID_Resol_512, &CEyeBodyView::OnResol512)
ON_COMMAND(ID_VIEW_PARARREL, &CEyeBodyView::OnViewPararrel)
ON_COMMAND(ID_VIEW_PERSPECTIVE, &CEyeBodyView::OnViewPerspective)
ON_COMMAND(ID_PROCESSOR_GPU, &CEyeBodyView::OnProcessorGpu)
ON_COMMAND(ID_PROCESSOR_CPU, &CEyeBodyView::OnProcessorCpu)
END_MESSAGE_MAP()

// CEyeBodyView 생성/소멸

CEyeBodyView::CEyeBodyView()
{
	// TODO: 여기에 생성 코드를 추가합니다.

}

CEyeBodyView::~CEyeBodyView()
{
}

BOOL CEyeBodyView::PreCreateWindow(CREATESTRUCT& cs)
{
	// TODO: CREATESTRUCT cs를 수정하여 여기에서
	//  Window 클래스 또는 스타일을 수정합니다.

	return CView::PreCreateWindow(cs);
}

// CEyeBodyView 그리기

void CEyeBodyView::OnDraw(CDC* /*pDC*/)
{
	CEyeBodyDoc* pDoc = GetDocument();
	ASSERT_VALID(pDoc);
	if (!pDoc)
		return;

	// TODO: 여기에 원시 데이터에 대한 그리기 코드를 추가합니다.
	DrawGLScene();
}


// CEyeBodyView 인쇄


void CEyeBodyView::OnFilePrintPreview()
{
#ifndef SHARED_HANDLERS
	AFXPrintPreview(this);
#endif
}

BOOL CEyeBodyView::OnPreparePrinting(CPrintInfo* pInfo)
{
	// 기본적인 준비
	return DoPreparePrinting(pInfo);
}

void CEyeBodyView::OnBeginPrinting(CDC* /*pDC*/, CPrintInfo* /*pInfo*/)
{
	// TODO: 인쇄하기 전에 추가 초기화 작업을 추가합니다.
}

void CEyeBodyView::OnEndPrinting(CDC* /*pDC*/, CPrintInfo* /*pInfo*/)
{
	// TODO: 인쇄 후 정리 작업을 추가합니다.
}

void CEyeBodyView::OnRButtonUp(UINT /* nFlags */, CPoint point)
{
	ClientToScreen(&point);
	OnContextMenu(this, point);
}

void CEyeBodyView::OnContextMenu(CWnd* /* pWnd */, CPoint point)
{
#ifndef SHARED_HANDLERS
	theApp.GetContextMenuManager()->ShowPopupMenu(IDR_POPUP_EDIT, point.x, point.y, this, TRUE);
#endif
}


// CEyeBodyView 진단

#ifdef _DEBUG
void CEyeBodyView::AssertValid() const
{
	CView::AssertValid();
}

void CEyeBodyView::Dump(CDumpContext& dc) const
{
	CView::Dump(dc);
}

CEyeBodyDoc* CEyeBodyView::GetDocument() const // 디버그되지 않은 버전은 인라인으로 지정됩니다.
{
	ASSERT(m_pDocument->IsKindOf(RUNTIME_CLASS(CEyeBodyDoc)));
	return (CEyeBodyDoc*)m_pDocument;
}
#endif //_DEBUG


// CEyeBodyView 메시지 처리기


BOOL CEyeBodyView::SetPixelformat(HDC hdc)
{
	int pixelformat;
	PIXELFORMATDESCRIPTOR pfd =
	{
		sizeof(PIXELFORMATDESCRIPTOR),
		1,
		PFD_DRAW_TO_WINDOW |
		PFD_SUPPORT_OPENGL |
		PFD_DOUBLEBUFFER,
		PFD_TYPE_RGBA,
		24,
		0, 0, 0, 0, 0, 0,
		0, 0,
		0, 0, 0, 0, 0,
		32,
		0,
		0,
		PFD_MAIN_PLANE,
		0,
		0, 0, 0
	};

	if ( (pixelformat = ChoosePixelFormat(hdc, &pfd))==FALSE) {
		MessageBox("ChoosePixelFormat failed", "Error", MB_OK); 
		return FALSE; 
	}


	if ( SetPixelFormat(hdc, pixelformat, &pfd) == FALSE) {
		MessageBox("SetPixelFormat failed", "Error", MB_OK);
	}
	return TRUE; 

}


int CEyeBodyView::OnCreate(LPCREATESTRUCT lpCreateStruct)
{
	if (CView::OnCreate(lpCreateStruct) == -1)
		return -1;

	// TODO:  여기에 특수화된 작성 코드를 추가합니다.
	m_hDC = GetDC()->m_hDC;
	if( !SetPixelformat(m_hDC))
		return -1; 
	//viewWidth = 256;
	//viewHeight = 256;
	
	// create rendering context and make it current
	m_hglRC = wglCreateContext(m_hDC);
	wglMakeCurrent(m_hDC, m_hglRC);
	
	LClick = false;
	GPUrendering = true;

	int a = 90*2;
	int b = 100*2;
	for(int i = 0; i < 512; i++){
		if(i < a)
			transfer[i].y = 0;	
		else if(b < i)		
			transfer[i].y = 300;
		else if(a <= i && i <= b)
			transfer[i].y = (((float)i-a)/(b-a))*300;	

	}

	for(int i = 0; i < 256; i++){
		alphaTable[i] = ((float)transfer[i*2].y+transfer[i*2+1].y)/600;

		if(i >= 95){//뼈
			colorTable[i].x = 0.933;
			colorTable[i].y = 0.909;
			colorTable[i].z = 0.886;
		} else if(i >= 85){//혈액?
			colorTable[i].x = 0.98; 
			colorTable[i].y = 0.42;
			colorTable[i].z = 0.34;
		} else if(i >= 70){
			colorTable[i].x = 0.90; 
			colorTable[i].y = 0.77;
			colorTable[i].z = 0.47;		
		}else{//살
			colorTable[i].x = 0.98; 
			colorTable[i].y = 0.870;
			colorTable[i].z = 0.776;
		}
	}

	
	//파일읽기
	FILE *fp = fopen("Bighead.den", "rb");
	fread(volume, 1, 256*256*225, fp);
	fclose(fp);

	volumeSize[0] = 256;
	volumeSize[1] = 256;
	volumeSize[2] = 225;

	if(GPUrendering){
		gpuRender.InitVolume((unsigned char*)volume, volumeSize);

		gpuRender.InitAlphaTable(alphaTable);
		gpuRender.InitColorTable(colorTable);

		gpuRender.InitGpuConst();
		gpuRender.InitColor();
		gpuRender.InitPixelBuffer();
	}
	else{
		cpuRender.InitVolume((unsigned char*)volume, volumeSize);

		cpuRender.InitAlphaTable(alphaTable);
		cpuRender.InitColorTable(colorTable);

		cpuRender.InitCpuConst();
		cpuRender.InitColor();
	}

	return 0;
}


void CEyeBodyView::OnDestroy()
{
	CView::OnDestroy();

	// TODO: 여기에 메시지 처리기 코드를 추가합니다.
	// deselect rendering context and delete it
	wglMakeCurrent(m_hDC, NULL);
	wglDeleteContext(m_hglRC);
}


void CEyeBodyView::OnSize(UINT nType, int cx, int cy)
{
	CView::OnSize(nType, cx, cy);

	// TODO: 여기에 메시지 처리기 코드를 추가합니다.
	ReSizeGLScene(cx, cy); 
}

void CEyeBodyView::ReSizeGLScene(GLsizei width, GLsizei height)
{	//화면크기조절
	if (height == 0 ) 	
		height = 1;

	// reset the viewport to new dimentions
	glViewport( 0, 0, width, height); 


	////안해도 상관없다
	//glMatrixMode( GL_PROJECTION); 
	//glLoadIdentity( );
	//
	//// calculate aspect ratio of the window
	//gluPerspective (45.f, (GLfloat)height/width, 0.1f, 1000.f );

	////set modelview matrix
	//glMatrixMode(GL_MODELVIEW); 
	//glLoadIdentity( );
}


void CEyeBodyView::DrawGLScene(void)
{
	// EyeBody 시점관련 함수들 - 안해도 상관없다
	// clear screen and depth buffer
	//glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT); 
	//glLoadIdentity( ); 
	//gluLookAt( 0.f, 0.f, 3.f,  0.f, 0.f, 0.f,  0.f, 1.f, 0.f ); 
		
	//렌더링
	if(GPUrendering){
		gpuRender.Rendering();
		gpuRender.DrawTexture();
	}
	else{
		cpuRender.Rendering();
		cpuRender.DrawTexture();
	}
	// swap buffer
	SwapBuffers( m_hDC ); 
}


void CEyeBodyView::OnLButtonDown(UINT nFlags, CPoint point)
{
	// TODO: 여기에 메시지 처리기 코드를 추가 및/또는 기본값을 호출합니다.
	LClick = true;
	beforePoint = point;

	CView::OnLButtonDown(nFlags, point);
}


void CEyeBodyView::OnChangeTransfer()
{
	// TODO: 여기에 명령 처리기 코드를 추가합니다.
	CTransferDlg dlg;
	dlg.DoModal();
}


void CEyeBodyView::OnMouseMove(UINT nFlags, CPoint point)
{
	// TODO: 여기에 메시지 처리기 코드를 추가 및/또는 기본값을 호출합니다.
	if(LClick == false)
		return;

	CPoint buf = point - beforePoint;

	//시점변경
	if(GPUrendering)
		gpuRender.MouseRotateEye(buf.x, buf.y);
	else
		cpuRender.MouseRotateEye(buf.x, buf.y);

	//렌더링
	DrawGLScene();

	beforePoint = point;
	CView::OnMouseMove(nFlags, point);
}

void CEyeBodyView::OnLButtonUp(UINT nFlags, CPoint point)
{
	// TODO: 여기에 메시지 처리기 코드를 추가 및/또는 기본값을 호출합니다.
	if(LClick == false)
		return;

	LClick = false;
	CView::OnLButtonUp(nFlags, point);
}

BOOL CEyeBodyView::OnMouseWheel(UINT nFlags, short zDelta, CPoint pt)
{
	// TODO: 여기에 메시지 처리기 코드를 추가 및/또는 기본값을 호출합니다.
	if(GPUrendering){
		if(zDelta > 0)
			gpuRender.ForwardEye(true);
		else 
			gpuRender.ForwardEye(false);
	}
	else{
		if(zDelta > 0)
			cpuRender.ForwardEye(true);
		else 
			cpuRender.ForwardEye(false);
	}
	//렌더링
	DrawGLScene();

	return CView::OnMouseWheel(nFlags, zDelta, pt);
}


void CEyeBodyView::OnResol256()
{
	// TODO: 여기에 명령 처리기 코드를 추가합니다.
	if(GPUrendering)
		gpuRender.ChangeResolution(256);
	else
		cpuRender.ChangeResolution(256);
	
	DrawGLScene();
}


void CEyeBodyView::OnResol512()
{
	// TODO: 여기에 명령 처리기 코드를 추가합니다.
	if(GPUrendering)
		gpuRender.ChangeResolution(512);
	else
		cpuRender.ChangeResolution(512);
	DrawGLScene();
}



void CEyeBodyView::OnViewPararrel()
{
	// TODO: 여기에 명령 처리기 코드를 추가합니다.
	if(GPUrendering)
		gpuRender.ChangeView(false);
	else
		cpuRender.ChangeView(false);
	DrawGLScene();
}


void CEyeBodyView::OnViewPerspective()
{
	// TODO: 여기에 명령 처리기 코드를 추가합니다.
	if(GPUrendering)
		gpuRender.ChangeView(true);
	else
		cpuRender.ChangeView(true);
	DrawGLScene();
}


void CEyeBodyView::OnProcessorGpu()
{
	// TODO: 여기에 명령 처리기 코드를 추가합니다.
	if(GPUrendering == false){
		GPUrendering = true;
		gpuRender.InitVolume((unsigned char*)volume, volumeSize);

		gpuRender.InitAlphaTable(alphaTable);
		gpuRender.InitColorTable(colorTable);

		gpuRender.InitGpuConst();
		gpuRender.InitColor();
		gpuRender.InitPixelBuffer();
	}
	DrawGLScene();
}


void CEyeBodyView::OnProcessorCpu()
{
	// TODO: 여기에 명령 처리기 코드를 추가합니다.
	if(GPUrendering == true){
		GPUrendering = false;
		gpuRender.EyeBodyCancel();
		cpuRender.InitVolume((unsigned char*)volume, volumeSize);

		cpuRender.InitAlphaTable(alphaTable);
		cpuRender.InitColorTable(colorTable);

		cpuRender.InitCpuConst();
		cpuRender.InitColor();
	}
	DrawGLScene();
}

