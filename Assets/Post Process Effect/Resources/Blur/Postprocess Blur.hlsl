#ifndef _POSTPROCESS_BLUR_INCLUDED
#define _POSTPROCESS_BLUR_INCLUDED
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

uniform float _SpatialWeight[5];

//x : 1/(sigma*sqrt(2*pi))  y: -1/(2*sigma*sigma) 
uniform float2 _ColorWeightParam;

float _BlurStepMultiple;

struct VaryingsGaussianBlur {
    float4 positionCS : SV_POSITION;
    float2 uv[5] : TEXCOORD0;
    UNITY_VERTEX_OUTPUT_STEREO
};

VaryingsGaussianBlur vertGaussianBlurH(Attributes input)
{
    VaryingsGaussianBlur output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    float4 pos = GetFullScreenTriangleVertexPosition(input.vertexID);
    float2 uv = GetFullScreenTriangleTexCoord(input.vertexID);

    output.positionCS = pos;
    float2 uvMid = DYNAMIC_SCALING_APPLY_SCALEBIAS(uv);

    float2 xLength = float2(_ScreenSize.z * (1 + max(_BlurStepMultiple - 1, 0)), 0);
    output.uv[0] = uvMid - 2 * xLength;
    output.uv[1] = uvMid - xLength;
    output.uv[2] = uvMid;
    output.uv[3] = uvMid + xLength;
    output.uv[4] = uvMid + 2 * xLength;


    return output;
}

VaryingsGaussianBlur vertGaussianBlurV(Attributes input)
{
    VaryingsGaussianBlur output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    float4 pos = GetFullScreenTriangleVertexPosition(input.vertexID);
    float2 uv = GetFullScreenTriangleTexCoord(input.vertexID);

    output.positionCS = pos;
    float2 uvMid = DYNAMIC_SCALING_APPLY_SCALEBIAS(uv);

    float2 yLength = float2(0, _ScreenSize.w * (1 + max(_BlurStepMultiple - 1, 0)));
    output.uv[0] = uvMid - 2 * yLength;
    output.uv[1] = uvMid - yLength;
    output.uv[2] = uvMid;
    output.uv[3] = uvMid + yLength;
    output.uv[4] = uvMid + 2 * yLength;


    return output;
}

half4 fragGaussianBlur(VaryingsGaussianBlur i) : SV_Target
{
    half4 color = half4(0, 0, 0, 0);
    for (int j = 0; j < 5; j++)
    {
        color += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, i.uv[j]) * _SpatialWeight[j];
    }
    return color;
}

struct VaryingsBilateralBlur {
    float4 positionCS : SV_POSITION;
    float2 uv[5] : TEXCOORD0;
    UNITY_VERTEX_OUTPUT_STEREO
};

VaryingsBilateralBlur vertBilateralBlurH(Attributes input)
{
    VaryingsBilateralBlur output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    float4 pos = GetFullScreenTriangleVertexPosition(input.vertexID);
    float2 uv = GetFullScreenTriangleTexCoord(input.vertexID);

    output.positionCS = pos;
    float2 uvMid = DYNAMIC_SCALING_APPLY_SCALEBIAS(uv);

    float2 xLength = float2(_ScreenSize.z * (1 + max(_BlurStepMultiple - 1, 0)), 0);
    output.uv[0] = uvMid - 2 * xLength;
    output.uv[1] = uvMid - xLength;
    output.uv[2] = uvMid;
    output.uv[3] = uvMid + xLength;
    output.uv[4] = uvMid + 2 * xLength;

    return output;
}

VaryingsBilateralBlur vertBilateralBlurV(Attributes input)
{
    VaryingsBilateralBlur output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    float4 pos = GetFullScreenTriangleVertexPosition(input.vertexID);
    float2 uv = GetFullScreenTriangleTexCoord(input.vertexID);

    output.positionCS = pos;
    float2 uvMid = DYNAMIC_SCALING_APPLY_SCALEBIAS(uv);

    float2 yLength = float2(0, _ScreenSize.w * (1 + max(_BlurStepMultiple - 1, 0)));
    output.uv[0] = uvMid - 2 * yLength;
    output.uv[1] = uvMid - yLength;
    output.uv[2] = uvMid;
    output.uv[3] = uvMid + yLength;
    output.uv[4] = uvMid + 2 * yLength;

    return output;
}

half4 fragBilateralBlur(VaryingsBilateralBlur i) : SV_Target
{
    half4 color = half4(0, 0, 0, 0);
    half weightSum = 0;

    half3 colorMid = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, i.uv[2]).rgb;
    for (int j = 0; j < 5; j++)
    {
        half3 colorSample = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, i.uv[j]).rgb;
        float colorDistinction = distance(colorSample, colorMid);
        float valueWeight = _ColorWeightParam.x * exp(colorDistinction * colorDistinction * _ColorWeightParam.y);

        float weight = _SpatialWeight[j] * valueWeight;
        color.xyz += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, i.uv[j]) * weight;
        weightSum += weight;
    }
    color /= weightSum;
    return color;
}




#endif
