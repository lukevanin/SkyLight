//
//  SIFTOrientation.metal
//  SkySight
//
//  Created by Luke Van In on 2023/01/07.
//

#include <metal_stdlib>

#include "Common.h"
#include "SIFTOrientation.h"

using namespace metal;


float orientationFromBin(float bin) {
    const int n = SIFT_ORIENTATION_HISTOGRAM_BINS;
    float t = bin / (float)n;
    float tau = 2 * M_PI_F;
    float orientation = t * tau;
    if (orientation > tau) {
        orientation -= tau;
    }
    if (orientation < 0) {
        orientation += tau;
    }
    return orientation;
}


float interpolatePeak(float h1, float h2, float h3) {
    return (h1 - h3) / (2 * (h1 + h3 - 2 * h2));
}
    
    
void getPrincipalOrientations(
    thread float * histogram,
    float orientationThreshold,
    thread int & orientationsCount,
    thread float * orientations
) {
    const int bins = SIFT_ORIENTATION_HISTOGRAM_BINS;
    
    float maximum = INT_MIN;
    for (int i = 0; i < bins; i++) {
        maximum = max(maximum, histogram[i]);
    }
    
    const float threshold = orientationThreshold * maximum;
    
    orientationsCount = 0;
    
    for (int i = 0; i < bins; i++) {
        float hm = histogram[((i - 1) + bins) % bins];
        float h0 = histogram[i];
        float hp = histogram[(i + 1) % bins];
        if ((h0 > threshold) && (h0 > hm) && (h0 > hp)) {
            float offset = interpolatePeak(hm, h0, hp);
            float orientation = orientationFromBin((float)i + offset);
            orientations[orientationsCount] = orientation;
            orientationsCount += 1;
        }
    }
}


void smoothHistogram(
    thread float * histogram,
    int iterations
) {
    const int n = SIFT_ORIENTATION_HISTOGRAM_BINS;
    float temp[n];
    for (int j = 0; j < iterations; j++) {
        for (int i = 0; i < n; i++) {
            temp[i] = histogram[i];
        }
        for (int i = 0; i < n; i++) {
            float h0 = temp[((i - 1) + n) % n];
            float h1 = temp[i];
            float h2 = temp[(i + 1) % n];
            float v = (h0 + h1 + h2) / 3.0;
            histogram[i] = v;
        }
    }
}


void getOrientationsHistogram(
    texture2d_array<float, access::read> g,
    int absoluteX,
    int absoluteY,
    int scale,
    float keypointSigma,
    float delta,
    float lambda,
    thread float * histogram
) {
//    let octave = dog.octaves[keypoint.octave]
    const int bins = SIFT_ORIENTATION_HISTOGRAM_BINS;
    int x = (float)absoluteX / delta;
    int y = (float)absoluteY / delta;
    float sigma = keypointSigma / delta;
//        let image = octave.gaussianImages[keypoint.scale]
//    let image = octaves[keypoint.octave].gradientImages[keypoint.scale]

//    let lambda = configuration.lambdaOrientation
    float exponentDenominator = 2.0 * lambda * lambda;
    
    int r = ceil(3 * lambda * sigma);
    
//    let bins = configuration.orientationBins
//    var histogram = Array<Float>(repeating: 0, count: bins)
    
    // TODO: Reject keypoints after interpolation
//    int minX = 1;
//    int minY = 1;
//    int maxX = g.get_width() - 2;
//    int maxY = g.get_height() - 2;
    
    // Reject keypoint outside of the image bounds
//    if ((x - r) < minX) {
//        return false;
//    }
//    if ((x + r) > maxX) {
//        return false;
//    }
//    if ((y - r) < minY) {
//        return false;
//    }
//    if ((y + r) > maxY) {
//        return false;
//    }
    
    for (int j = -r; j <= r; j++) {
        for (int i = -r; i <= r; i++) {

            // Gaussian weighting
            float u = (float)i / sigma;
            float v = (float)j / sigma;
            float r2 = u * u + v * v;
            float w = exp(-r2 / exponentDenominator);

            // Gradient orientation
            float2 gradient = g.read(ushort2(x + i, y + j), scale).rg;
            float orientation = gradient.x;
            float magnitude = gradient.y;
            
            // Add to histogram
            float t = orientation / (2 * M_PI_F);
            int bin = round(t * (float)bins);
            if (bin >= bins) {
                bin -= bins;
            }
            if (bin < 0) {
                bin += bins;
            }
            
            float m = w * magnitude;
            
            histogram[bin] += m;
        }
    }
}



kernel void siftOrientation(
    device SIFTOrientationResult * results [[buffer(0)]],
    device SIFTOrientationKeypoint * keypoints [[buffer(1)]],
    device SIFTOrientationParameters & parameters [[buffer(2)]],
    texture2d_array<float, access::read> gradientTextures [[texture(0)]],
    ushort gid [[thread_position_in_grid]]
) {
    SIFTOrientationResult result;
    const SIFTOrientationKeypoint keypoint = keypoints[gid];
    float histogram[SIFT_ORIENTATION_HISTOGRAM_BINS];
    getOrientationsHistogram(
        gradientTextures,
        keypoint.absoluteX,
        keypoint.absoluteY,
        keypoint.scale,
        keypoint.sigma,
        parameters.delta,
        parameters.lambda,
        histogram
    );
    smoothHistogram(histogram, 6);
    getPrincipalOrientations(
        histogram,
        parameters.orientationThreshold,
        result.count,
        result.orientations
    );
    results[gid] = result;
}
