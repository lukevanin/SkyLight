//
//  NearestNeighborDownScale.metal
//  SkySight
//
//  Created by Luke Van In on 2023/01/07.
//

#include <metal_stdlib>
using namespace metal;


kernel void nearestNeighborDownScale(
    texture2d<float, access::write> outputTexture [[texture(0)]],
    texture2d<float, access::read> inputTexture [[texture(1)]],
    ushort2 gid [[thread_position_in_grid]]
) {
    outputTexture.write(inputTexture.read(gid * 2), gid);
}
