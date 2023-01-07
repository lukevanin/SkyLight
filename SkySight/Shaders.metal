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


//constant float3x3 identity = float3x3(
//    float3(1, 0, 0),
//    float3(0, 1, 0),
//    float3(0, 0, 1)
//);

// Computes the inverse of a 3x3 matrix using the cross product and
// triple product.
// https://en.wikipedia.org/wiki/Invertible_matrix#Inversion_of_3_×_3_matrices
// See: https://www.onlinemathstutor.org/post/3x3_inverses
float3x3 invert(const float3x3 input) {
    const float3 x0 = input[0];
    const float3 x1 = input[1];
    const float3 x2 = input[2];

    const float d = determinant(input); // dot(x0, cross(x1, x2));

    const float3x3 cp = float3x3(
        cross(x1, x2),
        cross(x2, x0),
        cross(x0, x1)
    );
    return (1.0 / d) * cp;
}

// https://github.com/markkilgard/glut/blob/master/lib/gle/vvector.h
//#define SCALE_ADJOINT_3X3(a,s,m)                \
//{                                \
//   a[0][0] = (s) * (m[1][1] * m[2][2] - m[1][2] * m[2][1]);    \
//   a[1][0] = (s) * (m[1][2] * m[2][0] - m[1][0] * m[2][2]);    \
//   a[2][0] = (s) * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);    \
//                                \
//   a[0][1] = (s) * (m[0][2] * m[2][1] - m[0][1] * m[2][2]);    \
//   a[1][1] = (s) * (m[0][0] * m[2][2] - m[0][2] * m[2][0]);    \
//   a[2][1] = (s) * (m[0][1] * m[2][0] - m[0][0] * m[2][1]);    \
//                                \
//   a[0][2] = (s) * (m[0][1] * m[1][2] - m[0][2] * m[1][1]);    \
//   a[1][2] = (s) * (m[0][2] * m[1][0] - m[0][0] * m[1][2]);    \
//   a[2][2] = (s) * (m[0][0] * m[1][1] - m[0][1] * m[1][0]);    \
//}
//float3x3 scaleAdjoint(const float3x3 m, const float s) {
//    float3x3 a;
//    a[0][0] = (s) * (m[1][1] * m[2][2] - m[1][2] * m[2][1]);
//    a[1][0] = (s) * (m[1][2] * m[2][0] - m[1][0] * m[2][2]);
//    a[2][0] = (s) * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
//
//    a[0][1] = (s) * (m[0][2] * m[2][1] - m[0][1] * m[2][2]);
//    a[1][1] = (s) * (m[0][0] * m[2][2] - m[0][2] * m[2][0]);
//    a[2][1] = (s) * (m[0][1] * m[2][0] - m[0][0] * m[2][1]);
//
//    a[0][2] = (s) * (m[0][1] * m[1][2] - m[0][2] * m[1][1]);
//    a[1][2] = (s) * (m[0][2] * m[1][0] - m[0][0] * m[1][2]);
//    a[2][2] = (s) * (m[0][0] * m[1][1] - m[0][1] * m[1][0]);
//
//    return a;
//}

// https://github.com/markkilgard/glut/blob/master/lib/gle/vvector.h
//#define INVERT_3X3(b,det,a)            \
//{                        \
//   double tmp;                    \
//   DETERMINANT_3X3 (det, a);            \
//   tmp = 1.0 / (det);                \
//   SCALE_ADJOINT_3X3 (b, tmp, a);        \
//}
//float3x3 invert(const float3x3 input) {
//    float d = 1.0 / determinant(input);
//    return scaleAdjoint(input, d);
//}


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
}


static inline int symmetrizedCoordinates(int i, int l) {
    int ll = 2 * l;
    i = (i + ll) % (ll);
    if (i > l - 1){
        i = ll - 1 - i;
    }
    return i;
}


//static inline int2 symmetrizedCoordinates(const int2 c, const int2 d) {
//    return int2(
//         symmetrizedCoordinates(c.x, d.x),
//         symmetrizedCoordinates(c.y, d.y)
//    );
//}


kernel void siftGradient(
     texture2d<float, access::write> outputTexture [[texture(0)]],
     texture2d<float, access::read> inputTexture [[texture(1)]],
     ushort2 gid [[thread_position_in_grid]]
) {
    const int gx = (int)gid.x;
    const int gy = (int)gid.y;
    const int dx = inputTexture.get_width();
    const int dy = inputTexture.get_height();
    const ushort px = symmetrizedCoordinates(gx + 1, dx);
    const ushort mx = symmetrizedCoordinates(gx - 1, dx);
    const ushort py = symmetrizedCoordinates(gy + 1, dy);
    const ushort my = symmetrizedCoordinates(gy - 1, dy);
    const float tx = (inputTexture.read(ushort2(px, gy)).r - inputTexture.read(ushort2(mx, gy)).r) * 0.5;
    const float ty = (inputTexture.read(ushort2(gx, py)).r - inputTexture.read(ushort2(gx, my)).r) * 0.5;
    #warning("FIXME: IPOL implementation swaps dx and dy")
    float oa = atan2(tx, ty);
    float om = sqrt(tx * tx + ty * ty);
    outputTexture.write(float4(oa, om, 0, 0), gid);
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











bool isOnEdge(
    texture2d_array<float, access::read> t [[texture(0)]],
    int x,
    int y,
    int s,
    float edgeThreshold
) {
    const float v = t.read(ushort2(x, y), s).r;
    
    // Compute the 2d Hessian at pixel (i,j) - i = y, j = x
    // IPOL implementation uses hxx for y axis, and hyy for x axis
    const float zn = t.read(ushort2(x, y - 1), s).r;
    const float zp = t.read(ushort2(x, y + 1), s).r;
    const float pz = t.read(ushort2(x + 1, y), s).r;
    const float nz = t.read(ushort2(x - 1, y), s).r;
    const float pp = t.read(ushort2(x + 1, y + 1), s).r;
    const float np = t.read(ushort2(x - 1, y + 1), s).r;
    const float pn = t.read(ushort2(x + 1, y - 1), s).r;
    const float nn = t.read(ushort2(x - 1, y - 1), s).r;

    const float hxx = zn + zp - 2 * v;
    const float hyy = pz + nz - 2 * v;
    const float hxy = ((pp - np) - (pn - nn)) * 0.25;
    
    // Whess
    const float trace = hxx + hyy;
    const float determinant = (hxx * hyy) - (hxy * hxy);
    
    if (determinant <= 0) {
        // Negative determinant -> curvatures have different signs
        return true;
    }
    
//    let edgeThreshold = configuration.edgeThreshold
    const float threshold = ((edgeThreshold + 1) * (edgeThreshold + 1)) / edgeThreshold;
    const float curvature = (trace * trace) / determinant;
    
    if (curvature >= threshold) {
        // Feature is on an edge
        return true;
    }
    
    // Feature is not on an edge
    return false;
}


float3 derivatives3D(
    texture2d_array<float, access::read> t [[texture(0)]],
    int x,
    int y,
    int s
) {
    const float pzz = t.read(ushort2(x + 1, y), s).r;
    const float nzz = t.read(ushort2(x - 1, y), s).r;
    const float zpz = t.read(ushort2(x, y + 1), s).r;
    const float znz = t.read(ushort2(x, y - 1), s).r;
    const float zzp = t.read(ushort2(x, y), s + 1).r;
    const float zzn = t.read(ushort2(x, y), s - 1).r;

    // x: (i[c.z][c.x + 1, c.y] - i[c.z][c.x - 1, c.y]) * 0.5,
    // y: (i[c.z][c.x, c.y + 1] - i[c.z][c.x, c.y - 1]) * 0.5,
    // z: (i[c.z + 1][c.x, c.y] - i[c.z - 1][c.x, c.y]) * 0.5

    return float3(
        (pzz - nzz) * 0.5,
        (zpz - znz) * 0.5,
        (zzp - zzn) * 0.5
    );
}


float interpolateContrast(
    texture2d_array<float, access::read> t [[texture(0)]],
    int x,
    int y,
    int s,
    float3 alpha
) {
    const float3 dD = derivatives3D(t, x, y, s);
    const float3 c = dD * alpha;
    const float v = t.read(ushort2(x, y), s).r;
    return v + c.x * 0.5;
}


// Computes the 3D Hessian matrix.
//  ⎡ Ixx Ixy Ixs ⎤
//
//    Ixy Iyy Iys
//
//  ⎣ Ixs Iys Iss ⎦
float3x3 hessian3D(
    texture2d_array<float, access::read> t [[texture(0)]],
    int x,
    int y,
    int s
) {
    // z = zero, p = positive, n = negative
    const float zzz = t.read(ushort2(x, y), s).r;
    
    const float pzz = t.read(ushort2(x + 1, y), s).r;
    const float nzz = t.read(ushort2(x - 1, y), s).r;
    
    const float zpz = t.read(ushort2(x, y + 1), s).r;
    const float znz = t.read(ushort2(x, y - 1), s).r;

    const float zzp = t.read(ushort2(x, y), s + 1).r;
    const float zzn = t.read(ushort2(x, y), s - 1).r;
    
    const float ppz = t.read(ushort2(x + 1, y + 1), s).r;
    const float nnz = t.read(ushort2(x - 1, y - 1), s).r;
    
    const float npz = t.read(ushort2(x - 1, y + 1), s).r;
    const float pnz = t.read(ushort2(x + 1, y - 1), s).r;
    
    const float pzp = t.read(ushort2(x + 1, y), s + 1).r;
    const float nzp = t.read(ushort2(x - 1, y), s + 1).r;
    const float zpp = t.read(ushort2(x, y + 1), s + 1).r;
    const float znp = t.read(ushort2(x, y - 1), s + 1).r;
    
    const float pzn = t.read(ushort2(x + 1, y), s - 1).r;
    const float nzn = t.read(ushort2(x - 1, y), s - 1).r;
    const float zpn = t.read(ushort2(x, y + 1), s - 1).r;
    const float znn = t.read(ushort2(x, y - 1), s - 1).r;


    // let dxx = pzz + nzz - 2 * v
    // let dyy = zpz + znz - 2 * v
    // let dss = zzp + zzn - 2 * v
    const float dxx = pzz + nzz - 2 * zzz;
    const float dyy = zpz + znz - 2 * zzz;
    const float dss = zzp + zzn - 2 * zzz;

    // let dxy = (ppz - npz - pnz + nnz) * 0.25
    // let dxs = (pzp - nzp - pzn + nzn) * 0.25
    // let dys = (zpp - znp - zpn + znn) * 0.25

    const float dxy = (ppz - npz - pnz + nnz) * 0.25;
    const float dxs = (pzp - nzp - pzn + nzn) * 0.25;
    const float dys = (zpp - znp - zpn + znn) * 0.25;
    
    return float3x3(
        float3(dxx, dxy, dxs),
        float3(dxy, dyy, dys),
        float3(dxs, dys, dss)
    );
}


float3 interpolationStep(
    texture2d_array<float, access::read> t [[texture(0)]],
    int x,
    int y,
    int scale
) {
    const float3x3 H = hessian3D(t, x, y, scale);
    float3x3 Hi = -1.0 * invert(H);
//    for (int j = 0; j < 3; j++) {
//        for (int i = 0; i < 3; i++) {
//            Hi[i][j] = -H[i][j];
//        }
//    }
    
    const float3 dD = derivatives3D(t, x, y, scale);
    
    return Hi * dD;
}


bool outOfBounds(int x, int y, int scale, int width, int height, int scales) {
    // TODO: Configurable border.
    const int border = 5;
    const int minX = border;
    const int maxX = width - border - 1;
    const int minY = border;
    const int maxY = height - border - 1;
    const int minS = 1;
    const int maxS = scales;
    return x < minX || x > maxX || y < minY || y > maxY || scale < minS || scale > maxS;
}


struct InterpolateParameters {
    float dogThreshold;
    int maxIterations;
    float maxOffset;
    int width;
    int height;
    float octaveDelta;
    float edgeThreshold;
    int numberOfScales;
};


struct InputKeypoint {
    int x;
    int y;
    int scale;
    float value;
};


struct OutputKeypoint {
    int converged;
    int scale;
    float subScale;
    int relativeX;
    int relativeY;
    float absoluteX;
    float absoluteY;
    float value;
    float alphaX;
    float alphaY;
    float alphaZ;
};


kernel void siftInterpolate(
    device OutputKeypoint * outputKeypoints [[buffer(0)]],
    device InputKeypoint * inputKeypoints [[buffer(1)]],
    device InterpolateParameters & parameters [[buffer(2)]],
    texture2d_array<float, access::read> gradientTextures [[texture(0)]],
    ushort gid [[thread_position_in_grid]]
) {
    InputKeypoint input = inputKeypoints[gid];
    OutputKeypoint output;
    output.converged = 0;
    outputKeypoints[gid] = output;
    
    // Discard keypoint that is way below the brightness threshold
    if (abs(input.value) <= parameters.dogThreshold * 0.8) {
        return;
    }
        
    const int maxIterations = parameters.maxIterations;
    const float maxOffset = parameters.maxOffset;
    const int width = parameters.width;
    const int height = parameters.height;
    const int scales = parameters.numberOfScales;
    const float delta = parameters.octaveDelta;

    int x = input.x;
    int y = input.y;
    int scale = input.scale;

    if (outOfBounds(x, y, scale, width, height, scales)) {
        return;
    }

    bool converged = false;
    float3 alpha = float3(0);

    int i = 0;
    while (i < maxIterations) {
        alpha = interpolationStep(gradientTextures, x, y, scale);
            
        if ((abs(alpha.x) < maxOffset) && (abs(alpha.y) < maxOffset) && (abs(alpha.z) < maxOffset)) {
            converged = true;
            break;
        }
            
        // Whess
        // coordinate.x += Int(alpha.x.rounded())
        // coordinate.y += Int(alpha.y.rounded())
        // coordinate.z += Int(alpha.z.rounded())
        
        // IPOL
        // TODO: >=
        if (alpha.x > +maxOffset) {
            x += 1;
        }
        if (alpha.x < -maxOffset) {
            x -= 1;
        }
        if (alpha.y > +maxOffset) {
            y += 1;
        }
        if (alpha.y < -maxOffset) {
            y -= 1;
        }
        if (alpha.z > +maxOffset) {
            scale += 1;
        }
        if (alpha.z < -maxOffset) {
            scale -= 1;
        }
        
        if (outOfBounds(x, y, scale, width, height, scales)) {
            return;
        }
        
        i += 1;
    }
        
    if (!converged) {
        return;
    }

//    float newValue = interpolateContrast(gradientTextures, x, y, scale, alpha);
        
//    if (abs(newValue) <= parameters.dogThreshold) {
//        return;
//    }
        
    // Discard keypoint with high edge response
//    if (isOnEdge(gradientTextures, coordinate.x, coordinate.y, scale, parameters.edgeThreshold)) {
//        return;
//    }
        
//    float sigma = parameters.baseSigma * pow(parameters.sigmaRatio, alpha.z);


    // Return keypoint
    output.converged = 1;
    output.scale = scale;
    output.subScale = alpha.z;
    output.relativeX = x;
    output.relativeY = y;
    output.absoluteX = ((float)x + alpha.x) * delta;
    output.absoluteY = ((float)y + alpha.y) * delta;
    output.value = 0; //newValue;
    output.alphaX = alpha.x;
    output.alphaY = alpha.y;
    output.alphaZ = alpha.z;
    outputKeypoints[gid] = output;
    
//    output.converged = 1;
//    output.scale = scale;
//    output.subScale = 0;
//    output.relativeX = coordinate.x;
//    output.relativeY = coordinate.y;
//    output.absoluteX = coordinate.x * delta;
//    output.absoluteY = coordinate.y * delta;
//    output.value = gradientTextures.read(ushort2(coordinate.x, coordinate.y), scale).r;
//    outputKeypoints[gid] = output;
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
