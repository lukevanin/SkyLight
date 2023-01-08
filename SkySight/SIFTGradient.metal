//
//  SIFTGradient.metal
//  SkySight
//
//  Created by Luke Van In on 2023/01/07.
//

#include <metal_stdlib>

#include "Common.h"

using namespace metal;


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

