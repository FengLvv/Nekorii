#ifndef _VOLUME_CALCULATION_FUNCTION
#define _VOLUME_CALCULATION_FUNCTION
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
#include "Volume Calculation Function.hlsl"

//(1 - g)^2 / (4 * pi * (1 + g ^2 - 2 * g * cosθ) ^ 1.5 )
//_MieScatteringFactor.x = (1 - g) ^ 2 / 4 * pi
//_MieScatteringFactor.y =  1 + g ^ 2
//_MieScatteringFactor.z =  2 * g
float MieScatteringFunc(float3 lightDir, float3 cameraDir, float3 _MieScatteringFactor)
{
    //MieScattering: https://pic2.zhimg.com/v2-c65602e5c50e66eed7c2671f9fcff281_r.jpg
    // (1 - g)^2 / (4 * pi * (1 + g ^2 - 2 * g * cosθ) ^ 1.5 )
    // largest when lightDir(pos to light) = -cameraDir(pos to camera)
    float lightCos = dot(lightDir, -cameraDir);
    return _MieScatteringFactor.x / pow((_MieScatteringFactor.y - _MieScatteringFactor.z * lightCos), 1.5);
}

float Beer(float stepLength, float _Density, float _ExtinctionFactor)
{
    //can sample from a 3D texture
    float density = _Density;
    float extinction = _ExtinctionFactor * stepLength * density;
    return exp(-extinction);
}


// input screen uv, output posWS, set the depth as _BlitTexture
float3 GetPixelWorldPosition(float2 uv)
{
    // sample depth texture
    half4 blitDepth = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, uv);
    // get the 01 depth
    float depthValue = Linear01Depth(blitDepth.x, _ZBufferParams);

    // get the far point in clip cube far plane
    float3 farPosCS = float3(uv.x * 2 - 1, uv.y * 2 - 1, 1) * _ProjectionParams.z;
    // get the far point in view frumstum
    float3 farPosVS = mul(unity_CameraInvProjection, farPosCS.xyzz).xyz;

    // get posVS of aiming point, transform to world space 
    float3 posVS = farPosVS * depthValue;
    float3 posWS = TransformViewToWorld(posVS);
    return posWS;
}
#endif
