#include "funset.hpp"
#include <iostream>
#include <cuda_runtime.h> // For the CUDA runtime routines (prefixed with "cuda_")
#include <device_launch_parameters.h>
#include "common.hpp"

__global__ static void image_normalize(const float* src, float* dst, int count, int offset)
{
	int index = threadIdx.x + blockIdx.x * blockDim.x;
	if (index > count - 1) return;

	const float* input = src + index * offset;
	float* output = dst + index * offset;
	float mean{ 0.f }, sd{ 0.f };

	for (size_t i = 0; i < offset; ++i) {
		mean += input[i];
		sd += pow(input[i], 2.f);
		output[i] = input[i];
	}

	mean /= offset;
	sd /= offset;
	sd -= pow(mean, 2.f);
	sd = sqrt(sd);
	if (sd < EPS_) sd = 1.f;

	for (size_t i = 0; i < offset; ++i) {
		output[i] = (input[i] - mean) / sd;
	}
}

int image_normalize_gpu(const float* src, float* dst, int width, int height, int channels, float* elapsed_time)
{
	/* cudaEvent_t: CUDA event types,�ṹ������, CUDA�¼�,���ڲ���GPU��ĳ
	�������ϻ��ѵ�ʱ��,CUDA�е��¼���������һ��GPUʱ���,����CUDA�¼�����
	GPU��ʵ�ֵ�,������ǲ����ڶ�ͬʱ�����豸�������������Ļ�ϴ����ʱ */
	cudaEvent_t start, stop;
	// cudaEventCreate: ����һ���¼�����,�첽����
	cudaEventCreate(&start);
	cudaEventCreate(&stop);
	// cudaEventRecord: ��¼һ���¼�,�첽����,start��¼��ʼʱ��
	cudaEventRecord(start, 0);

	float *dev_src{ nullptr }, *dev_dst{ nullptr };
	size_t length{ width * height * channels * sizeof(float) };

	// cudaMalloc: ���豸�˷����ڴ�
	cudaMalloc(&dev_src, length);
	cudaMalloc(&dev_dst, length);

	/* cudaMemcpy: �������˺��豸�˿�������,�˺������ĸ���������������֮һ:
	(1). cudaMemcpyHostToHost: �������ݴ������˵�������
	(2). cudaMemcpyHostToDevice: �������ݴ������˵��豸��
	(3). cudaMemcpyDeviceToHost: �������ݴ��豸�˵�������
	(4). cudaMemcpyDeviceToDevice: �������ݴ��豸�˵��豸��
	(5). cudaMemcpyDefault: ��ָ��ֵ�Զ��ƶϿ������ݷ���,��Ҫ֧��
	ͳһ����Ѱַ(CUDA6.0�����ϰ汾)
	cudaMemcpy��������������ͬ���� */
	cudaMemcpy(dev_src, src, length, cudaMemcpyHostToDevice);

	image_normalize << < 2, 256 >> >(dev_src, dev_dst, channels, width*height);

	cudaMemcpy(dst, dev_dst, length, cudaMemcpyDeviceToHost);

	// cudaFree: �ͷ��豸����cudaMalloc����������ڴ�
	cudaFree(dev_src);
	cudaFree(dev_dst);

	// cudaEventRecord: ��¼һ���¼�,�첽����,stop��¼����ʱ��
	cudaEventRecord(stop, 0);
	// cudaEventSynchronize: �¼�ͬ��,�ȴ�һ���¼����,�첽����
	cudaEventSynchronize(stop);
	// cudaEventElapseTime: ���������¼�֮�侭����ʱ��,��λΪ����,�첽����
	cudaEventElapsedTime(elapsed_time, start, stop);
	// cudaEventDestroy: �����¼�����,�첽����
	cudaEventDestroy(start);
	cudaEventDestroy(stop);

	return 0;
}

