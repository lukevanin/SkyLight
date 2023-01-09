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
    texture2d_array<float, access::write> outputTexture [[texture(0)]],
    texture2d_array<float, access::read> inputTexture [[texture(1)]],
    ushort3 gid [[thread_position_in_grid]]
) {
    // Thread group runs [0...output.width - 2][0...output.height - 2]
    
    const float value = inputTexture.read(gid.xy + 1, gid.z + 1).r;
    const int2 center = int2(gid.xy);
    
    float minValue = +1000;
    float maxValue = -1000;

    for (int i = 0; i < 26; i++) {
        int3 neighborOffset = neighborOffsets[i];
        ushort textureIndex = gid.z + neighborOffset.x;
        int2 neighborDelta = int2(neighborOffset.yz);
        ushort2 coordinate = ushort2(center + neighborDelta);
        float neighborValue = inputTexture.read(coordinate + 1, textureIndex).r;

        minValue = min(minValue, neighborValue);
        maxValue = max(maxValue, neighborValue);
    }
    
    float result = 0;
    
    if ((value < minValue) || (value > maxValue)) {
        result = 1;
    }

    outputTexture.write(float4(result, 0, 0, 1), gid.xy + 1, gid.z);
}

