//
//  Shaders.metal
//  SkySight
//
//  Created by Luke Van In on 2022/12/10.
//

#include <metal_stdlib>
using namespace metal;


// https://en.wikipedia.org/wiki/Invertible_matrix#Inversion_of_2_×_2_matrices
bool invert(const float2x2 input, thread float2x2 & output) {
    float a = input[0][0];
    float b = input[1][0];
    float c = input[0][1];
    float d = input[1][1];
    
    float p = (a * d) - (b * c);
    
    if (p == 0) {
        return false;
    }
    
    float q = 1.0 / p;
    output = float2x2(
        float2(q * d, q * -c),
        float2(q * -b, q * a)
    );
    return true;
}


// https://metalbyexample.com/fundamentals-of-image-processing/
float gaussian(float x, float y, float sigma) {
    float ss = sigma * sigma;
    float xx = x * x;
    float yy = y * y;
    float base = sqrt(2 * M_PI_F * ss);
    float exponent = (xx + yy) / (2 * ss);
    return (1 / base) * exp(-exponent);
}


kernel void convertSRGBToGraysale(
    texture2d<float, access::write> outputTexture [[texture(0)]],
    texture2d<float, access::read> inputTexture [[texture(1)]],
    ushort2 gid [[thread_position_in_grid]]
) {
    const float4 input = inputTexture.read(gid);
    const float i = 0 +
        (0.212639005871510 * input.r) +
        (0.715168678767756 * input.g) +
        (0.072192315360734 * input.b);
    const float4 output = float4(i, i, i, input.a);
    outputTexture.write(output, gid);
}


kernel void subtract(
    texture2d<float, access::write> outputTexture [[texture(0)]],
    texture2d<float, access::read> inputTexture0 [[texture(1)]],
    texture2d<float, access::read> inputTexture1 [[texture(2)]],
    ushort2 gid [[thread_position_in_grid]]
) {
    float4 a = inputTexture0.read(gid);
    float4 b = inputTexture1.read(gid);
    float4 c = a - b;
    outputTexture.write(c, gid);
}


kernel void nearestNeighborDownScale(
    texture2d<float, access::write> outputTexture [[texture(0)]],
    texture2d<float, access::read> inputTexture [[texture(1)]],
    ushort2 gid [[thread_position_in_grid]]
) {
    outputTexture.write(inputTexture.read(gid * 2), gid);
}


kernel void nearestNeighborUpScale(
    texture2d<float, access::write> outputTexture [[texture(0)]],
    texture2d<float, access::read> inputTexture [[texture(1)]],
    ushort2 gid [[thread_position_in_grid]]
) {
    ushort2 inputSize = ushort2(inputTexture.get_width(), inputTexture.get_height());
    ushort2 outputSize = ushort2(outputTexture.get_width(), outputTexture.get_height());

    ushort2 scale = outputSize / inputSize;
    outputTexture.write(inputTexture.read(gid / scale), gid);
}


kernel void bilinearUpScale(
    texture2d<float, access::write> outputTexture [[texture(0)]],
    texture2d<float, access::read> inputTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    
    const int wo = outputTexture.get_width();
    const int ho = outputTexture.get_height();
    
    const int wi = inputTexture.get_width();
    const int hi = inputTexture.get_height();
    
    const float dx = (float)wi / (float)wo;
    const float dy = (float)hi / (float)ho;
    
    int i = gid.x;
    int j = gid.y;
    const float x = (float)i * dx;
    const float y = (float)j * dy;
    int im = (int)x;
    int jm = (int)y;
    int ip = im + 1;
    int jp = jm + 1;
    
    //image extension by symmetrization
    if (ip >= wi) {
        ip = 2 * wi - 1 - ip;
    }
    if (im >= wi) {
        im = 2 * wi - 1 - im;
    }
    if (jp >= hi) {
        jp = 2 * hi - 1 - jp;
    }
    if (jm >= hi) {
        jm = 2 * hi - 1 - jm;
    }

    const float fractional_x = x - floor(x);
    const float fractional_y = y - floor(y);
    
    const float c0 = inputTexture.read(uint2(ip, jp)).r;
    const float c1 = inputTexture.read(uint2(ip, jm)).r;
    const float c2 = inputTexture.read(uint2(im, jp)).r;
    const float c3 = inputTexture.read(uint2(im, jm)).r;

    const float output = fractional_x * (fractional_y * c0
                           + (1 - fractional_y) * c1 )
             + (1 - fractional_x) * ( fractional_y  * c2
                           + (1 - fractional_y) * c3 );

    outputTexture.write(float4(output, 0, 0, 1), gid);


//    const c = inputTexture.read(ushort2())
}


static inline int symmetrizedCoordinates(int i, int l) {
    int ll = 2*l;
    i = (i+ll)%(ll);
    if(i>l-1){i = ll-1-i;}
    return i;
}


kernel void convolutionX(
    texture2d<float, access::write> outputTexture [[texture(0)]],
    texture2d<float, access::read> inputTexture [[texture(1)]],
    device float * weights [[buffer(0)]],
    device uint & numberOfWeights [[buffer(1)]],
    ushort2 gid [[thread_position_in_grid]]
) {
    const int width = inputTexture.get_width();
    
    float sum = 0;
    const int n = (int)numberOfWeights;
    const int o = (int)gid.x - (n / 2);
    for (int i = 0; i < n; i++) {
        int x = symmetrizedCoordinates(o + i, width);
        sum += weights[i] * inputTexture.read(ushort2(x, gid.y)).r;
    }
    outputTexture.write(float4(sum, 0, 0, 1), gid);
}


kernel void convolutionY(
    texture2d<float, access::write> outputTexture [[texture(0)]],
    texture2d<float, access::read> inputTexture [[texture(1)]],
    device float * weights [[buffer(0)]],
    device uint & numberOfWeights [[buffer(1)]],
    ushort2 gid [[thread_position_in_grid]]
) {
    const int height = inputTexture.get_height();
    
    float sum = 0;
    const int n = (int)numberOfWeights;
    const int o = (int)gid.y - (n / 2);
    for (int i = 0; i < n; i++) {
        int y = symmetrizedCoordinates(o + i, height);
        sum += weights[i] * inputTexture.read(ushort2(gid.x, y)).r;
    }
    outputTexture.write(float4(sum, 0, 0, 1), gid);
}


constant int3 neighborOffsets[] = {
    int3(0, -1, -1),
    int3(0,  0, -1),
    int3(0, +1, -1),
    int3(0, -1,  0),
    int3(0,  0,  0),
    int3(0, +1,  0),
    int3(0, -1, +1),
    int3(0,  0, +1),
    int3(0, +1, +1),
    
    int3(1, -1, -1),
    int3(1,  0, -1),
    int3(1, +1, -1),
    int3(1, -1,  0),
    
    int3(1, +1,  0),
    int3(1, -1, +1),
    int3(1,  0, +1),
    int3(1, +1, +1),
    
    int3(2, -1, -1),
    int3(2,  0, -1),
    int3(2, +1, -1),
    int3(2, -1,  0),
    int3(2,  0,  0),
    int3(2, +1,  0),
    int3(2, -1, +1),
    int3(2,  0, +1),
    int3(2, +1, +1),
};


kernel void siftExtrema(
    texture2d<float, access::write> outputTexture [[texture(0)]],
    texture2d<float, access::read> inputTexture0 [[texture(1)]],
    texture2d<float, access::read> inputTexture1 [[texture(2)]],
    texture2d<float, access::read> inputTexture2 [[texture(3)]],
    ushort2 gid [[thread_position_in_grid]]
) {
    const texture2d<float, access::read> w[] = {
        inputTexture0,
        inputTexture1,
        inputTexture2,
    };
    
    int s = 1;
//    int m = gid.x;
//    int n = gid.y;
    const float value = w[s].read(gid).r;
    const int2 center = int2(gid);
    
    float minValue = 10000;
    float maxValue = -1000;

    for (int i = 0; i < 26; i++) {
        int3 neighborOffset = neighborOffsets[i];
        ushort textureIndex = neighborOffset.x;
        texture2d<float, access::read> texture = w[textureIndex];
        int2 neighborDelta = int2(neighborOffset.yz);
        ushort2 coordinate = ushort2(center + neighborDelta);
        float neighborValue = texture.read(coordinate).r;

        minValue = min(minValue, neighborValue);
        maxValue = max(maxValue, neighborValue);
    }
    
    float result = 0;
    
    if ((value < minValue) || (value > maxValue)) {
        result = 1;
    }

    outputTexture.write(float4(result, value, 0, 1), gid);
}


// https://en.wikipedia.org/wiki/Lucas–Kanade_method
kernel void lucasKanade(
    texture2d<float, access::read_write> outputTexture [[texture(0)]],
    texture2d<float, access::read> ixTexture [[texture(1)]],
    texture2d<float, access::read> iyTexture [[texture(2)]],
    texture2d<float, access::read> itTexture [[texture(3)]],
    ushort2 gid [[thread_position_in_grid]]
) {
    const int k = 3;

    const int minX = k;
    const int minY = k;
    const int maxX = outputTexture.get_width() - 1 - k;
    const int maxY = outputTexture.get_height() - 1 - k;

    const int2 o = int2(gid.x, gid.y);

    float2x2 Ai;
    float2x2 A;

    float a = 0;
    float b = 0;
    float c = 0;
    float d = 0;
    float u = 0;
    float v = 0;
    float2 p0;
    float2 p1;
    float2 p2;
    
    if (o.x <= minX || o.x >= maxX || o.y <= minY || o.y >= maxY) {
        outputTexture.write(float4(0, 0, 0, 1), gid);
        return;
    }

    for (int j = -k; j <= k; j++) {
        for (int i = -k; i <= k; i++) {
            
            ushort2 g = ushort2(o + int2(i, j));
            
            float w = gaussian(i, j, k);

            float ix = ixTexture.read(g).r * w;
            float iy = iyTexture.read(g).r * w;
            float it = itTexture.read(g).r * w;

            a += (ix * ix);
            b += (ix * iy);
            c += (iy * ix);
            d += (iy * iy);
            
            u += (ix * it);
            v += (iy * it);
        }
    }
    
    A = float2x2(float2(a, c), float2(b, d));
    
    if (invert(A, Ai)) {
        float2 f = float2(u, v);
        p1 = Ai * -f;
    }
    else {
        p1 = float2(0, 0);
    }

    // Blend the new frame with the old frame.
    // t is the ratio of the new frame to use.
    float t = 0.1;
    p0 = outputTexture.read(gid).rg;
    p2 = ((1.0 - t) * p0) + (t * p1);
    
    outputTexture.write(float4(p2, 0, 1), gid);
}
