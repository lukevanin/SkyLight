//
//  SIFTExtrema.metal
//  SkySight
//
//  Created by Luke Van In on 2023/01/07.
//

#include <metal_stdlib>
using namespace metal;

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

