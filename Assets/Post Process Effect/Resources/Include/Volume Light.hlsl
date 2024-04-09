#ifndef _VOLUME_LIGHT_INCLUDED
#define _VOLUME_LIGHT_INCLUDED

#define MAIN_LIGHT_CALCULATE_SHADOWS 
#define _MAIN_LIGHT_SHADOWS_CASCADE 
#define RandomJitter(seed) frac((1664525.0 * seed + 1013904223.0) / 4294967296.0)
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
#include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
#include "Volume Calculation Function.hlsl"

int _MarchSteps;
int _MaxStepDistance;
float _NearPlaneDistance;
float _FarPointDistance;
float4 _MieScatteringFactor;
float _ExtinctionFactor;
float3 _LightPowerColorEnhance;
float _Density;

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

VaryingsVL vertVL(Attributes input)
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

half4 fragVL(VaryingsVL i) : SV_Target
{
    // test  
    Light mainLight = GetMainLight();

    // initial position
    float3 pixelPosWS = GetPixelWorldPosition(i.uv);
    float3 cameraPosWS = GetCameraPositionWS();
    float3 rayDirNormalize = normalize(pixelPosWS - cameraPosWS);
    cameraPosWS = cameraPosWS + rayDirNormalize * _NearPlaneDistance;
    pixelPosWS = pixelPosWS - rayDirNormalize * _FarPointDistance;
    float3 rayDir = min(length(pixelPosWS - cameraPosWS), _MaxStepDistance) * rayDirNormalize;

    float3 marchVector = rayDir / _MarchSteps;
    float marchLength = length(marchVector);
    float3 marchingPosWS = cameraPosWS;

    // ray marching to camera        
    half3 shaftLight = 0;
    UNITY_LOOP
    for (float x = 0; x < _MarchSteps; x++)
    {
        float jitterX = InterleavedGradientNoise(marchingPosWS.xy * 592826, 0);
        float jitterY = InterleavedGradientNoise(marchingPosWS.yy * 105656, 0);
        float jitterZ = InterleavedGradientNoise(marchingPosWS.zy * 105561, 0);
        float3 jitterPos = float3(jitterX, jitterY, jitterZ) * 2 - 1;
        jitterPos = jitterPos * float3(0.2, 0.2, 0.2);

        float inShadow = GetLightAttenuation(marchingPosWS + jitterPos);
        // light power * density * step length * in Shadow
        float3 lightPower = (mainLight.color + _LightPowerColorEnhance) * length(marchVector) * _Density;
        // light attenuation by HG phase function
        float hg = MieScatteringFuncHG(normalize(mainLight.direction), -rayDirNormalize, _MieScatteringFactor);
        // light attenuation by Beer's law
        float beer = Beer(marchLength * (x + 1), _Density,_ExtinctionFactor);

        shaftLight += lightPower * hg * beer * _ExtinctionFactor * inShadow;
        marchingPosWS += marchVector;
    }

    // half4 blit = float4(0,1,0,1);     
    return float4((shaftLight), 1);
}
#endif
