#ifndef _SSR
#define _SSR

#define MAIN_LIGHT_CALCULATE_SHADOWS 
#define _MAIN_LIGHT_SHADOWS_CASCADE 
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
#include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
#include "Volume Calculation Function.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

int _MarchSteps;
float _DepthTolerance;


struct VaryingsVL {
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_OUTPUT_STEREO
};

float GetLightAttenuation(float3 position)
{
    // Transform posWS to shadow coord
    float4 shadowPos = TransformWorldToShadowCoord(position);
    float intensity = MainLightRealtimeShadow(shadowPos);
    return intensity;
}

VaryingsVL vertSSR(Attributes input)
{
    VaryingsVL output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    float4 pos = GetFullScreenTriangleVertexPosition(input.vertexID);
    float2 uv = GetFullScreenTriangleTexCoord(input.vertexID);

    output.positionCS = pos;
    output.uv = DYNAMIC_SCALING_APPLY_SCALEBIAS(uv);

    return output;
}

bool MarchDDA(inout float2 marchPosUV, inout float2 pixelBase, float invertStartDepth, float invertEndDepth, float2 startPosUV, float2 endPosUV, float2 marchDirUVNormalized, float2 perPixelSize)
{
    float k = marchDirUVNormalized.y / marchDirUVNormalized.x;
    if (abs(marchDirUVNormalized.y / marchDirUVNormalized.x) < 1)
    {
        //move per x        
        marchPosUV += float2(1, k) * perPixelSize.x;
        pixelBase.x += perPixelSize.x * sign(marchDirUVNormalized.x);
        if (abs(marchPosUV.y - pixelBase.y) > perPixelSize.y)
        {
            pixelBase.y += perPixelSize.y * sign(marchDirUVNormalized.y);
        }

        float marchRatio = (marchPosUV.x - startPosUV.x) / (endPosUV.x - startPosUV.x);

        float invertDepth = lerp(invertStartDepth, invertEndDepth, marchRatio);
        float marchDepth = 1.0 / invertDepth;

        //compare depth
        half blitDepth = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, pixelBase + perPixelSize * 0.5 * sign(marchDirUVNormalized)).x;
        float uvPosDepth = LinearEyeDepth(blitDepth, _ZBufferParams);

        return uvPosDepth < marchDepth && distance(marchDepth, uvPosDepth) < _DepthTolerance && pixelBase.x > 0 && pixelBase.y > 0 && pixelBase.x < 1 && pixelBase.y < 1;
    }
    else
    {
        //move per y
        marchPosUV += float2(1 / k, 1) * perPixelSize.y;
        pixelBase.y += perPixelSize.y * sign(marchDirUVNormalized.y);
        if (abs(marchPosUV.x - pixelBase.x) > perPixelSize.x)
        {
            pixelBase.x += perPixelSize.x * sign(marchDirUVNormalized.x);
        }

        float marchRatio = (marchPosUV.y - startPosUV.y) / (endPosUV.y - startPosUV.y);

        float invertDepth = lerp(invertStartDepth, invertEndDepth, marchRatio);
        float marchDepth = 1.0 / invertDepth;

        //compare depth
        half blitDepth = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, pixelBase + perPixelSize * 0.5 * sign(marchDirUVNormalized)).x;
        float uvPosDepth = LinearEyeDepth(blitDepth, _ZBufferParams);

        return uvPosDepth < marchDepth && distance(marchDepth, uvPosDepth) < _DepthTolerance && pixelBase.x > 0 && pixelBase.y > 0 && pixelBase.x < 1 && pixelBase.y < 1;
    }
}



half4 fragSSR(VaryingsVL i) : SV_Target
{
    // _MarchSteps =2000;
    // _DepthTolerance = 2;


    float2 perPixelSize = float2(1.0 / _ScreenParams.x, 1.0 / _ScreenParams.y);

    // pixel corner near to origin
    float2 pixelBase;
    modf(i.uv / perPixelSize, pixelBase);
    pixelBase *= perPixelSize;

    float marchStartPosDepth;
    // initial position
    float3 pixelPosWS = GetPixelWorldPosition(i.uv, marchStartPosDepth);
    marchStartPosDepth *= _ProjectionParams.z;

    float3 cameraPosWS = GetCameraPositionWS();
    float3 pixelDirNormalizeWS = normalize(pixelPosWS - cameraPosWS);

    float3 normalDirWS = SampleSceneNormals(i.uv);
    float3 marchDirWS = normalize(reflect(pixelDirNormalizeWS, normalDirWS));

    // use uv space DDA to march
    // https://zhuanlan.zhihu.com/p/686833098
    // float3 marchPosWS = pixelPosWS + marchDirWS * 0.01;
    float3 marchEndPosWS = pixelPosWS + marchDirWS * 50;

    float marchEndPosDepth = -TransformWorldToView(marchEndPosWS).z;
    // 1/depth is linear
    float invertStartPointDepth = 1.0 / marchStartPosDepth;
    float invertEndPosDepth = 1.0 / marchEndPosDepth;

    // uv position
    float2 marchPosUV = i.uv;
    float2 marchStartPosUV = i.uv;
    float2 marchEndPosUV = ComputeNormalizedDeviceCoordinatesWithZ(marchEndPosWS, UNITY_MATRIX_VP).xy;

    // how far the world ray move when uv move 1
    float2 marchDirUVNormalized = normalize(marchEndPosUV - marchStartPosUV);

    float4 reflectColor = float4(0, 0, 0, 0);

    float marchDepth = marchStartPosDepth;
    UNITY_LOOP
    for (int stepNum = 1; stepNum < _MarchSteps; stepNum++)
    {
        if (MarchDDA(marchPosUV, pixelBase, invertStartPointDepth, invertEndPosDepth, marchStartPosUV, marchEndPosUV, marchDirUVNormalized, perPixelSize))
        {
            reflectColor.xyz = SampleSceneColor(pixelBase + perPixelSize * 0.5 * sign(marchDirUVNormalized)).rgb;
            reflectColor.w = 1;
            break;
        }
    }

    // half4 blit = float4(0,1,0,1);     
    // return float4((normalDirWS), 1);
    // reflectColor = SampleSceneColor( i.uv).rgb;

    return reflectColor;
    return float4((marchEndPosDepth.xxx / _ProjectionParams.z), 1);
}

TEXTURE2D(_ReflectionTex);
SAMPLER(sampler_ReflectionTex);

struct AttributeDrawSSR {
    float4 positionOS : POSITION;
    float2 uv : TEXCOORD0;
    float3 normalOS : NORMAL;
};

struct VaryingsDrawSSR {
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD1;
    float2 uv : TEXCOORD0;
    float3 normalWS : TEXCOORD2;
};

VaryingsDrawSSR vertDrawSSR(AttributeDrawSSR input)
{
    VaryingsDrawSSR output;
    output.positionCS = TransformObjectToHClip(input.positionOS);
    output.positionWS = TransformObjectToWorld(input.positionOS);
    output.uv = input.uv;
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    return output;
}

half4 fragRenderReflection(VaryingsDrawSSR i) : SV_Target
{
    float3 lightDir = GetMainLight().direction;
    float2 screenUV = i.positionCS.xy / _ScreenParams.xy;
    float3 reflectColor = SAMPLE_TEXTURE2D(_ReflectionTex, sampler_ReflectionTex, screenUV).rgb;
    float nDotl = dot(lightDir, i.normalWS);
    float fresnel = 1 - nDotl;
    fresnel = fresnel * fresnel * fresnel * fresnel * fresnel;
    reflectColor *= fresnel;
    return float4(reflectColor, 1);
}

#endif
