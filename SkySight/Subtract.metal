//
//  Subtract.metal
//  SkySight
//
//  Created by Luke Van In on 2023/01/07.
//

#include <metal_stdlib>
using namespace metal;


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


