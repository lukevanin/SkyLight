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

//float2 gaussian2(float2 c, float sigma) {
//    return float2(gaussian1(c.x, sigma), gaussian1(c.y, sigma));
//}


// https://en.wikipedia.org/wiki/Lucas–Kanade_method
kernel void lucasKanade(
    texture2d<float, access::read_write> outputTexture [[texture(0)]],
    texture2d<float, access::read> ixTexture [[texture(1)]],
    texture2d<float, access::read> iyTexture [[texture(2)]],
    texture2d<float, access::read> itTexture [[texture(3)]],
    ushort2 gid [[thread_position_in_grid]]
) {
//    float2 d = float2(w, h);
//    float2 p = float2(gid.x, gid.y);
//    float4 c = float4(p.x / d.x, p.y / d.y, 0, 1);
//    float4 c = float4(p.x / d.x, 0, 0, 1);
//    float4 c = float4(0, p.y / d.y, 0, 1);
//    outputTexture.write(c, gid);
//    return;

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
            
            float dx = float(i) / float(k);
            float dy = float(j) / float(k);
            float w = gaussian(dx, dy, k);

            float ix = ixTexture.read(g).r * w;
            float iy = iyTexture.read(g).r * w;
            float it = itTexture.read(g).r;

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

//    float2 q = float2(normalize(p), length(p));

    float t = 0.1;
    p0 = outputTexture.read(gid).rg;
    p2 = ((1.0 - t) * p0) + (t * p1);
    
    outputTexture.write(float4(p2, 0, 1), gid);
}
