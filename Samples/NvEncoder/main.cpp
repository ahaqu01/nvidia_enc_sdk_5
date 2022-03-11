#include "NvEncoder.h"
#include <iostream>
#include <opencv2/opencv.hpp>
#include <opencv2/core/core.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <iostream>
#include "rgb2yuv.cuh"

using namespace std;
using namespace cv;


int main()
{
	CNvEncoder nvEncoder;
	return nvEncoder.zyhMain();
}

