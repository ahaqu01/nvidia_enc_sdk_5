#include<time.h>
#include<iostream>
#include<opencv/highgui.h>
#include<opencv2/opencv.hpp>
#include<opencv/cxcore.h>
#include<opencv2/highgui/highgui.hpp>
#include<opencv2/imgproc/imgproc.hpp>
# include <stdio.h>
# include <stdlib.h>

//CUDA RunTime API
#include <cuda_runtime.h>
using namespace std;
using namespace cv;
#define BLOCK_SIZE 32 //每个块的线程数 32*32
#define PIC_BLOCK 1 //每个线程处理图像块 5*5
//#define GRID_SIZE 16
//const int block_num=480;
//static const int N = 25;

//__device__ int flag;


//超清公式

#define RGB2Y(R, G, B)  ( 16  + 0.183f * (R) + 0.614f * (G) + 0.062f * (B) )
#define RGB2U(R, G, B)  ( 128 - 0.101f * (R) - 0.339f * (G) + 0.439f * (B) )
#define RGB2V(R, G, B)  ( 128 + 0.439f * (R) - 0.399f * (G) - 0.040f * (B) )

/*
#define RGB2Y(R, G, B)  ( 16  + 0.257f * (R) + 0.504f * (G) + 0.098f * (B) )
#define RGB2U(R, G, B)  ( 128 - 0.148f * (R) - 0.291f * (G) + 0.439f * (B) )
#define RGB2V(R, G, B)  ( 128 + 0.439f * (R) - 0.368f * (G) - 0.071f * (B) )
*/

/*
#define RGB2Y(R, G, B)  ( 0.299f * (R) + 0.587f * (G) + 0.114f * (B) )
#define RGB2U(R, G, B)  ( -0.147f * (R) - 0.28886f * (G) + 0.436f * (B) )
#define RGB2V(R, G, B)  ( 0.615f * (R) - 0.51499f * (G) - 0.10001f * (B) )
*/

#define YUV2R(Y, U, V) ( 1.164f *((Y) - 16) + 1.792f * ((V) - 128) )
#define YUV2G(Y, U, V) ( 1.164f *((Y) - 16) - 0.213f *((U) - 128) - 0.534f *((V) - 128) )
#define YUV2B(Y, U, V) ( 1.164f *((Y) - 16) + 2.114f *((U) - 128))

#define CLIPVALUE(x, minValue, maxValue) ((x) < (minValue) ? (minValue) : ((x) > (maxValue) ? (maxValue) : (x)))

__global__ static void __RgbToYuv420p(const unsigned char* dpRgbData, size_t rgbPitch, unsigned char* dpYuv420pData, size_t yuv420Pitch, int width, int height)
{
	int index = blockIdx.x * blockDim.x + threadIdx.x;
    //for(int index=0;index<width*height;index++)
    //{
    //printf("index=%d\n",index);
	int w = index % yuv420Pitch; //线程对应的RGB图像列
	int h = index / yuv420Pitch; //线程对应的RGB图像行
    
	if (w >= width || h >= height)
		return;
        
    //printf("index=%d\t",index);
    //printf("w=%d,h=%d\n",w,h);
	unsigned char* dp_y_data = dpYuv420pData; //y通道存在前width*height数组中
	unsigned char* dp_u_data = dp_y_data + height * yuv420Pitch;  //yuv420Pitch RGB图像的列长
	unsigned char* dp_v_data = dp_u_data + height * yuv420Pitch / 4;
    //printf("h=%d,w=%d,rgbPitch=%d\t",h,w,rgbPitch);
	unsigned char r = dpRgbData[h * rgbPitch + w * 3 + 0]; //rgbPitch RGB图像的列长
	unsigned char g = dpRgbData[h * rgbPitch + w * 3 + 1];
	unsigned char b = dpRgbData[h * rgbPitch + w * 3 + 2];

	dp_y_data[h   * yuv420Pitch + w] = (unsigned char)(CLIPVALUE(RGB2Y(r, g, b), 0, 255));
	int num = h / 2 * width / 2 + w / 2;
	int offset = num / width * (yuv420Pitch - width);

	if (h % 2 == 0 && w % 2 == 0)
	{
		dp_u_data[num + offset] = (unsigned char)(CLIPVALUE(RGB2U(r, g, b), 0, 255));
		dp_v_data[num + offset] = (unsigned char)(CLIPVALUE(RGB2V(r, g, b), 0, 255));
	}
    
    //printf("in __RgbToYuv420p\n");
    //printf("%d,%d,%d\t",dpYuv420pData[h * yuv420Pitch + w],dp_u_data[num + offset],dp_v_data[num + offset]);
    //printf("[%d,%d,%d]\t",r,g,b);
    //printf("%d\t",dpYuv420pData[h * yuv420Pitch + w]);
    //printf("\n");
    
    #if 0
    if(threadIdx.x==0)
    {
        //printf("dp_y_data=%d,dp_u_data=%d,dp_v_data=%d\n",dp_y_data[h * yuv420Pitch + w],dp_u_data[num + offset],dp_v_data[num + offset]);
        printf("dpYuv420pData[h * yuv420Pitch + w]=%d\n",dpYuv420pData[h * yuv420Pitch + w]);
    }
    #endif
    //}
}


__global__ static void __RgbToNv12(const unsigned char* dpRgbData, size_t rgbPitch, unsigned char* dpNv12Data, size_t nv12Pitch, int width, int height)
{
	int index = blockIdx.x * blockDim.x + threadIdx.x;
	int w = index % nv12Pitch;
	int h = index / nv12Pitch;

	if (w >= width || h >= height)
		return;

	unsigned char* dp_y_data = dpNv12Data;
	unsigned char* dp_u_data = dp_y_data + height * nv12Pitch;
	
	unsigned char r = dpRgbData[h * rgbPitch + w * 3 + 0];
	unsigned char g = dpRgbData[h * rgbPitch + w * 3 + 1];
	unsigned char b = dpRgbData[h * rgbPitch + w * 3 + 2];

	dp_y_data[h * nv12Pitch + w] = (unsigned char)CLIPVALUE(RGB2Y(r, g, b), 0, 255);
	int num = (h / 2 * width / 2 + w / 2);
	int offset = (num * 2 + 1) / width * (nv12Pitch - width);

	if (h % 2 == 0 && w % 2 == 0)
	{
		dp_u_data[num * 2 + 0 + offset] = (unsigned char)(CLIPVALUE(RGB2U(r, g, b), 0, 255));
		dp_u_data[num * 2 + 1 + offset] = (unsigned char)(CLIPVALUE(RGB2V(r, g, b), 0, 255));
	}
}

__global__ static void __RgbToYuv422p(const unsigned char* dpRgbData, size_t rgbPitch, unsigned char* dpYuv422pData, size_t yuv422pPitch, int width, int height)
{
	int index = blockIdx.x * blockDim.x + threadIdx.x;
	int w = index % yuv422pPitch;
	int h = index / yuv422pPitch;

	if (w >= width || h >= height)
		return;

	unsigned char* dp_y_data = dpYuv422pData;
	unsigned char* dp_u_data = dp_y_data + height * yuv422pPitch;
	unsigned char* dp_v_data = dp_u_data + height / 2 * yuv422pPitch;

	unsigned char r = dpRgbData[h * rgbPitch + w * 3 + 0];
	unsigned char g = dpRgbData[h * rgbPitch + w * 3 + 1];
	unsigned char b = dpRgbData[h * rgbPitch + w * 3 + 2];

	dp_y_data[h * yuv422pPitch + w] = (unsigned char)CLIPVALUE(RGB2Y(r, g, b), 0, 255);
	int num = h * width / 2 + w / 2;
	int offset = num / width * (yuv422pPitch - width);

	if (w % 2 == 0)
	{
		dp_u_data[num + offset] = (unsigned char)(CLIPVALUE(RGB2U(r, g, b), 0, 255));
		dp_v_data[num + offset] = (unsigned char)(CLIPVALUE(RGB2V(r, g, b), 0, 255));
	}
}


__global__ void print_cuda_dst(uchar *cuda_dst,int rows,int cols)
{
    printf("\n");
    for(int i=0;i<rows*cols*3;i++)
    {
        //printf("in cuda\n");
        printf("%d\t",cuda_dst[i]);
    }
    printf("\n");
}

//指针作为参数传入函数时，只是将指针变量中存储的地址值传入函数，
//在函数内改变了形参的地址值并不会对函数外的指针产生影响
void rgb2yuv(cv::Mat& rgb_img,uchar* yuv_img_buff[])
{
	//printf("in CUDA\n");
	//声明变量
	//bgr图像
	uchar* cuda_src = NULL;
	//yuv图像 destination
	uchar* cuda_dst = NULL;


	//分配空间
    int len_src=sizeof(uchar)*rgb_img.rows*rgb_img.cols*3; //RGB图像大小
    int len_dst=sizeof(uchar)*rgb_img.rows*rgb_img.cols*3/2; //YUV图像大小
	cudaMalloc((void**)&cuda_src,len_src);
	cudaMalloc((void**)&cuda_dst,len_dst);
    
    /*
	//初始化为0
	cudaMemset(change, 0, sizeof(float)*bx*by);
    */
    
	//cpu->gpu
	cudaMemcpy(cuda_src, rgb_img.data, len_src, cudaMemcpyHostToDevice);

    //分块
	//bx*by块，每个块 BLOCK_SIZE*BLOCK_SIZE个线程（32的倍数最好），每个线程负责pic_block*pic_block小块
	int bx = ((rgb_img.cols + BLOCK_SIZE - 1) / BLOCK_SIZE + PIC_BLOCK - 1) / PIC_BLOCK;
	int by = ((rgb_img.rows + BLOCK_SIZE - 1) / BLOCK_SIZE + PIC_BLOCK - 1) / PIC_BLOCK;
    //printf("bx=%d,by=%d\n",bx,by);
	dim3 blocks(bx*by);
	dim3 threads(BLOCK_SIZE*BLOCK_SIZE);
    
    //dim3 blocks(1);
	//dim3 threads(1);
    size_t rgbPitch=3*rgb_img.cols; //记得乘3！！！！！
    size_t yuv420Pitch=rgb_img.cols;
    //printf("rgbPitch=%d\n",rgbPitch);
	__RgbToYuv420p <<<blocks, threads >>> (cuda_src, rgbPitch,cuda_dst,yuv420Pitch,rgb_img.cols, rgb_img.rows);
      //__RgbToYuv422p<<<blocks, threads >>> (cuda_src, rgbPitch,cuda_dst,yuv420Pitch,rgb_img.cols, rgb_img.rows);
	//gpu->cpu
    /*
    YUV420图像的U/V分量在水平和垂直方向上downsample，在水平和垂直方向上的数据都只有Y分量的一半。
    因此总体来说，U/V分量的数据量分别只有Y分量的1/4，不能作为Mat类型的一个channel。
    所以通常YUV420图像的全部数据存储在Mat的一个channel，比如CV_8UC1，这样对于Mat来说，
    图像的大小就有变化。对于MxN（rows x cols，M行N列）的BGR图像（CV_8UC3);
    其对应的YUV420图像大小是(3M/2)xN（CV_8UC1）。
    前MxN个数据是Y分量，后(M/2)xN个数据是U/V分量，UV数据各占一半。
    */
    
#if 1
    int y_len=sizeof(uchar)*rgb_img.rows*rgb_img.cols;
    int u_len=sizeof(uchar)*rgb_img.rows/2*rgb_img.cols/2;
    int v_len=sizeof(uchar)*rgb_img.rows/2*rgb_img.cols/2;
    cudaMemcpy(yuv_img_buff[0], cuda_dst, y_len, cudaMemcpyDeviceToHost);
    cudaMemcpy(yuv_img_buff[1], cuda_dst+y_len, u_len, cudaMemcpyDeviceToHost);
    cudaMemcpy(yuv_img_buff[2], cuda_dst+y_len+u_len, v_len, cudaMemcpyDeviceToHost);
    
    
    //print_cuda_dst<<<1,1>>>(cuda_dst,rgb_img.rows,rgb_img.cols);
    //print_cuda_dst<<<1,1>>>(cuda_src,rgb_img.rows,rgb_img.cols);
#endif
    
    
#if 0
    Mat yuv_img = Mat::zeros(rgb_img.rows*3/2, rgb_img.cols, CV_8UC1);
	cudaMemcpy(yuv_img.data, cuda_dst, len_dst, cudaMemcpyDeviceToHost);
    //printf("sizeof(uchar)*rgb_img->rows*rgb_img->cols*3/2=%d\n",sizeof(uchar)*rgb_img->rows*rgb_img->cols*3/2);
    printf("-----------------------");
    //yuv2BGR
    Mat rgbimg(rgb_img.rows,rgb_img.cols,CV_8UC3);
    cvtColor(yuv_img,rgbimg,CV_YUV420p2RGB);
    imwrite("yuv.jpg",rgbimg);
    
    //print_cuda_dst<<<1,1>>>(cuda_src);
    /*
    for(int i=0;i<100;i++)
    {
        for (int j=0;j<1;j++)
        {
            printf("%d\t",yuv_img.data[i]);
        }
        printf("\n");
    }
    */
#endif
	//free
	//printf("int cuda free\n");
	cudaFree(cuda_src);
	cudaFree(cuda_dst);

}

