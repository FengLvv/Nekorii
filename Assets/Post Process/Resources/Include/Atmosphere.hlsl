#ifndef _VOLUME_LIGHT_INCLUDED
#define _VOLUME_LIGHT_INCLUDED

#define MAIN_LIGHT_CALCULATE_SHADOWS 
#define _MAIN_LIGHT_SHADOWS_CASCADE 
#define RandomJitter(seed) frac((1664525.0 * seed + 1013904223.0) / 4294967296.0)
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
#include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
#include "../Include/Volume Calculation Function.hlsl"

int _MarchSteps;
int _MaxStepDistance;
float _NearPlaneDistance;
float _FarPointDistance;
float4 _MieScatteringFactor;
float _ExtinctionFactor;
float3 _LightPowerColorEnhance;
float _Density;
// todo: set in c#
int _MarchStepsAtmosphere;
int _MarchStepsSun;
float _PlanetRadius;
float _AtmosphereHeight;
// rayleigh scattering and mie scattering
float2 _DensityScaleHeight;
float3 _ScatterParamR;
float3 _ScatterParamM;
float _RayleighWeight;
float _MieWeight;
float _GroundStepScale;


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

VaryingsVL vertAtmosphere(Attributes input)
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



// input height, output density of Rayleigh and Mie scattering
float2 CalculateDensityTerm(float height)
{
    return exp(-height.xx / _DensityScaleHeight);
}

half4 fragAtmosphere(VaryingsVL i) : SV_Target
{
    float4 outColor = float4(0, 0, 0, 1);
    Light mainLight = GetMainLight();
    float3 lightColor = mainLight.color * _LightPowerColorEnhance;
    float3 lightDir = normalize(mainLight.direction);


    // initial position
    float3 pixelPosWS = GetPixelWorldPosition(i.uv);
    float3 cameraPosWS = GetCameraPositionWS();
    float3 ray = pixelPosWS - cameraPosWS;
    float3 rayDirNormalize = normalize(ray);
    float rayLength = length(ray);
    float skyMask = step(0.999, rayLength / _ProjectionParams.z);
    // set the sky to infinite far
    rayLength = lerp(rayLength, Max_float(), skyMask);

    // cameraPosWS = cameraPosWS + rayDirNormalize * _NearPlaneDistance;
    // pixelPosWS = pixelPosWS - rayDirNormalize * _FarPointDistance;
    // float rayLength = min(length(pixelPosWS - cameraPosWS), _MaxStepDistance);

    // float3 ray = rayLength * rayDirNormalize;
    // float3 marchVector = ray / _MarchSteps;
    // float marchLength = length(marchVector);
    //
    // // ray marching from camera
    // half3 shaftLight = 0;
    // float3 marchPosWS = cameraPosWS;
    // UNITY_LOOP
    // for (float x = 0; x < _MarchSteps; x++)
    // {
    //     float jitterX = InterleavedGradientNoise(marchPosWS.xy * 592826, 0);
    //     float jitterY = InterleavedGradientNoise(marchPosWS.yy * 105656, 0);
    //     float jitterZ = InterleavedGradientNoise(marchPosWS.zy * 105561, 0);
    //     float3 jitterPos = float3(jitterX, jitterY, jitterZ) * 2 - 1;
    //     jitterPos = jitterPos * float3(0.2, 0.2, 0.2);
    //
    //     float inShadow = GetLightAttenuation(marchPosWS + jitterPos);
    //     // light power * density * step length * in Shadow
    //     float3 lightPower = lightColor * length(marchVector) * _Density;
    //     // light attenuation by HG phase function
    //     float hg = MieScatteringFuncHG(normalize(mainLight.direction), -rayDirNormalize, _MieScatteringFactor);
    //     // light attenuation by Beer's law
    //     float beer = Beer(marchLength * (x + 1), _Density, _ExtinctionFactor);
    //
    //     shaftLight += lightPower * hg * beer * _ExtinctionFactor * inShadow;
    //     marchPosWS += marchVector;
    // }


    // Atmosphere color
    // Postulate standing on the top of ground, the atmosphere center is at (0, -_PlanetRadius, 0)
    float3 atmosphereCenter = float3(0, -_PlanetRadius, 0);

    // distance between camera and atmosphere, if intersect with ground, the distance is the distance to ground
    // if not, the distance is the distance to atmosphere
    // since the ray have 2 intersection points with the sphere, we need to choose the nearest one
    float distanceToGround = RaySphereIntersection(cameraPosWS, rayDirNormalize, atmosphereCenter, _PlanetRadius).x;
    if (distanceToGround > 0)
    {
        rayLength = min(rayLength, distanceToGround);
    }
    else
    {
        // since the ray have one forward intersection point with the sphere, we need to choose the positive result
        float distanceToAtmosphere = RaySphereIntersection(cameraPosWS, rayDirNormalize, atmosphereCenter, _PlanetRadius + _AtmosphereHeight).y;
        rayLength = min(rayLength, distanceToAtmosphere);
    }


    float3 rayEnd = cameraPosWS + rayLength * rayDirNormalize;
    float3 marchVector = (rayEnd - cameraPosWS) / _MarchStepsAtmosphere;
    float marchSize = length(marchVector);

    // density sum along the camera ray
    float2 densityRay = 0;
    float3 extinctionR = 0;
    float3 extinctionM = 0;
    float3 marchPos = cameraPosWS;
    float3 skyColor;
    // ray marching towards view direction
    for (int stepRay = 0; stepRay < _MarchStepsAtmosphere; stepRay++)
    {
        marchPos += marchVector;

        float jitterX = InterleavedGradientNoise(marchPos.xy * 592826, 0);
        float jitterY = InterleavedGradientNoise(marchPos.yy * 105656, 0);
        float jitterZ = InterleavedGradientNoise(marchPos.zy * 105561, 0);
        float3 jitterPos = float3(jitterX, jitterY, jitterZ) * 2 - 1;
        jitterPos *= 300;

        float3 marchPosJitter = marchPos + jitterPos;
        // height towards the atmosphere center(circle)
        float height = length(marchPosJitter - atmosphereCenter) - _PlanetRadius;
        // local density * ds
        float2 localDensity = CalculateDensityTerm(height) * marchSize;
        if (skyMask < 0.01)
        {
           localDensity *=  _GroundStepScale;                
        }
        densityRay += localDensity;

        float inShadow = GetLightAttenuation(marchPos + jitterPos * 0.001);

        // density sum along the light ray
        float2 densityLight = 0;
        if (inShadow > 0.5)
        {
            float3 lightPos = marchPosJitter;
            float distanceLight = RaySphereIntersection(lightPos, lightDir, atmosphereCenter, _PlanetRadius + _AtmosphereHeight).y;
            float3 rayEndLight = lightPos + distanceLight * lightDir;
            float3 marchVectorLight = (rayEndLight - lightPos) / _MarchStepsSun;
            float marchSizeLight = length(marchVectorLight);
            for (int stepRayLight = 0; stepRayLight < _MarchStepsSun; stepRayLight++)
            {
                lightPos += marchVectorLight;
                float heightLight = length(lightPos - atmosphereCenter) - _PlanetRadius;
                float2 localDensityLight = CalculateDensityTerm(heightLight);
                densityLight += localDensityLight * marchSizeLight;
            }

            // accumulate on the ray: ray shoot to point, get radiance and multiply the density and step, then shoot to camera
            // calculate the light attenuation: T(c.x) * T(x,s) = exp( -(densityC + densityS) * \beta_0 )
            float2 sumDensity = densityRay + densityLight;
            float3 tR = exp(-sumDensity.x * _ScatterParamR);
            float3 tM = exp(-sumDensity.y * _ScatterParamM);
            // T * beta_h * ds = T * beta_0 * local density * ds ( color*extinction=in-scatter )
            extinctionR += tR * _ScatterParamR * localDensity.x;
            extinctionM += tM * _ScatterParamM * localDensity.y;
        }
    }
    float3 phaseR = RayleighPhaseFunc(lightDir, -rayDirNormalize);
    float3 phaseM = MieScatteringFuncHG(lightDir, -rayDirNormalize, _MieScatteringFactor);
    // sun intensity * phase * extinction * weight
    float3 colorR = lightColor * extinctionR * phaseR * _RayleighWeight;
    float3 colorM = lightColor * extinctionM * phaseM * _MieWeight;
    skyColor = colorR + colorM;

    outColor.xyz = skyColor;


    if (skyMask < 0.01)
    {
        // if the light ray shoot an object, the color is combined with two parts
        // 1. the color scattered from atmosphere
        // 2. the object color attenuated by the camera ray
        // so calculate the transmittance of the camera ray, set as the alpha channel, which means
        // how much light can pass through the camera ray
        // blend formula: oriCol * transmittance + atmosphereCol
        float3 rayTransmittance = exp(-(densityRay.x * _ScatterParamR + densityRay.y * _ScatterParamM));

        outColor.a = rayTransmittance;
    }


    // half4 blit = float4(0,1,0,1);

    return outColor;
}




#endif
