#ifndef _VOLUME_CALCULATION_FUNCTION
#define _VOLUME_CALCULATION_FUNCTION
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

float4 _MieScatteringFactor;

half3 CalculateRayleighScatter(float h, float H)
{
    half3 rayleighScatter = half3(33.1, 13.5, 5.8);
    return rayleighScatter * exp(-h / H);
}

half3 CalculateMieScatter(float h, float H)
{
    half3 mieScatter = half3(0.21, 0.21, 0.21);
    return mieScatter * exp(-h / H);
}

half3 CalculateRayleighExtinction(half3 cameraDir, half3 lightDir)
{
    float u = dot(-cameraDir, lightDir);
     return 0.0596831036595 * (1.0 + u * u);
}

//(1 - g)^2 / (4 * pi * (1 + g ^2 - 2 * g * cosθ) ^ 1.5 )
//MieScatteringFactor.x = (1 - g) ^ 2 / 4 * pi
//MieScatteringFactor.y =  1 + g ^ 2
//MieScatteringFactor.z =  2 * g
float MieScatteringFuncHG(float3 lightDir, float3 cameraDir )
{
    //MieScattering: https://pic2.zhimg.com/v2-c65602e5c50e66eed7c2671f9fcff281_r.jpg
    // (1 - g)^2 / (4 * pi * (1 + g ^2 - 2 * g * cosθ) ^ 1.5 )
    // largest when lightDir(pos to light) = -cameraDir(pos to camera)
    float lightCos = dot(lightDir, -cameraDir);
    return _MieScatteringFactor.x / pow((_MieScatteringFactor.y - _MieScatteringFactor.z * lightCos), 1.5);
}

float RayleighPhaseFunc(float3 lightDir, float3 cameraDir)
{
    // 3 / (16 * pi) * (1 + cos^2θ)
    // largest when lightDir(pos to light) = -cameraDir(pos to camera)
    float lightCos = dot(lightDir, -cameraDir);
    return 3.0 / (16.0 * PI) * (1 + lightCos * lightCos);
}


float Beer(float stepLength, float Density, float sigma_t)
{
    //can sample from a 3D texture
    float extinction = stepLength * Density * sigma_t;
    return exp(-extinction);
}


// input screen uv, output posWS, set the depth as _BlitTexture
float3 GetPixelWorldPosition(float2 uv,out float depthValue01)
{
    // sample depth texture
    half4 blitDepth = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, uv);
    // get the 01 depth
    depthValue01 = Linear01Depth(blitDepth.x, _ZBufferParams);

    // get the far point in clip cube far plane
    float3 farPosCS = float3(uv.x * 2 - 1, uv.y * 2 - 1, 1) * _ProjectionParams.z;
    // get the far point in view frumstum
    float3 farPosVS = mul(unity_CameraInvProjection, farPosCS.xyzz).xyz;

    // get posVS of aiming point, transform to world space 
    float3 posVS = farPosVS * depthValue01;
    float3 posWS = TransformViewToWorld(posVS);
    return posWS;
}

float3 GetPixelWorldPosition(float2 uv)
{
    float depthValue;
    return GetPixelWorldPosition(uv, depthValue);
}

// return two intersection points distance of ray and sphere  
float2 RaySphereIntersection(float3 rayOrigin, float3 rayDir, float3 sphereCenter, float sphereRadius)
{
    rayOrigin -= sphereCenter;
    float a = dot(rayDir, rayDir);
    float b = 2.0 * dot(rayOrigin, rayDir);
    float c = dot(rayOrigin, rayOrigin) - (sphereRadius * sphereRadius);
    float d = b * b - 4 * a * c;
    if (d < 0)
    {
        return -1;
    }
    else
    {
        d = sqrt(d);
        return float2(-b - d, -b + d) / (2 * a);
    }
}

// return two intersection points of ray and sphere
void RaySphereIntersection(float3 rayOrigin, float3 rayDir, float3 sphereCenter, float sphereRadius, out float3 intersectionFront , out float3 intersectionBack)
{
    float2 intersection = RaySphereIntersection(rayOrigin, rayDir, sphereCenter, sphereRadius);
    if (intersection.x < 0)
    {
        intersection.x = intersection.y;
    }

    intersectionFront = rayOrigin + rayDir * intersection.y;
    intersectionBack = rayOrigin + rayDir * intersection.x;
}


//density总密度=\sum局部密度，步长
float BeerPowder(float density)
{
    float powder = 1.0 - exp(-density * 2.0);
    float beers = exp(-density);
    float light_energy = 2.0 * beers * powder;
    return beers;
}


#endif
