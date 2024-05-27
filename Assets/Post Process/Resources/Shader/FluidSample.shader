Shader "Custom/FluidSample "
{
    Properties //着色器的输入    
    {
        _JitterSize("Jitter Size", Float) = 1
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

    CBUFFER_START(UnityPerMaterial)
        float _JitterSize;
    CBUFFER_END

    float _ZValue;
    float3 _FluidCenter;
    float _FluidSize;
    float _DensityMultiply;

    TEXTURE3D(_GasVelocity); //贴图采样    
    SAMPLER(sampler_GasVelocity);

    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
    #include  "../Include/Volume Calculation Function.hlsl"
    #include  "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"



    struct VaryingsFluid //片元着色器  
    {
        float4 positionCS: SV_POSITION;
        float2 uv: TEXCOORD0;
    };


    VaryingsFluid vert(Attributes input)
    {
        VaryingsFluid output;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

        float4 pos = GetFullScreenTriangleVertexPosition(input.vertexID);
        float2 uv = GetFullScreenTriangleTexCoord(input.vertexID);

        output.positionCS = pos;
        output.uv = DYNAMIC_SCALING_APPLY_SCALEBIAS(uv);
        return output;
    }



    bool IntersectAABB(float3 rayOrigin, float3 rayDir, float3 aabbPosWS, float aabbSize, out float maxOfTMin, out float minOfTMax)
    {
        float3 aabbMin = aabbPosWS - aabbSize / 2;
        float3 aabbMax = aabbPosWS + aabbSize / 2;

        float3 boxMinTime = (aabbMin - rayOrigin) / rayDir;
        float3 boxMaxTime = (aabbMax - rayOrigin) / rayDir;

        float3 tmin = min(boxMinTime, boxMaxTime);
        float3 tmax = max(boxMinTime, boxMaxTime);

        maxOfTMin = max(0, max(max(tmin.x, tmin.y), tmin.z));
        minOfTMax = max(0, min(min(tmax.x, tmax.y), tmax.z));

        return maxOfTMin < minOfTMax;
    }

    float3 GetUVWInAABB(float3 posWS, float3 aabbPosWS, float aabbSize)
    {
        float3 aabbMin = aabbPosWS - aabbSize / 2;
        float3 uvw = (posWS - aabbMin) / aabbSize;
        return uvw;
    }


    half4 frag(VaryingsFluid i) : SV_Target
    {
        Light mainLight = GetMainLight();
        float3 lightDir = mainLight.direction;
        float3 lightColor = mainLight.color;

        float3 cameraPosWS = _WorldSpaceCameraPos;
        float3 posNDCFar = float3(i.uv * 2 - 1, 1);
        float3 posCSFar = posNDCFar * _ProjectionParams.z;
        float4 posVSFar = mul(unity_CameraInvProjection, posCSFar.xyzz);
        float3 posWSFar = TransformViewToWorld(posVSFar.xyz);

        float3 rayOrigin = cameraPosWS;
        float3 rayDirWS = normalize(posWSFar.xyz - rayOrigin);

        float maxOfTMin, minOfTMax;
        bool intersect = IntersectAABB(rayOrigin, rayDirWS, _FluidCenter, _FluidSize, maxOfTMin, minOfTMax);
        if (!intersect)
        {
            return 0;
        }

        float steps = 50.;
        float3 marchPos = rayOrigin + rayDirWS * maxOfTMin;
        float3 marchEnd = rayOrigin + rayDirWS * minOfTMax;
        float3 marchStep = (marchEnd - marchPos) / steps;
        float3 densityAttenuationAlongCamRay = 1;
        float4 color = 0;
        for (int step = 0; step < steps; step++)
        {
            marchPos += marchStep;
            float3 sampleMarchPos = marchPos +  (float3(GenerateHashedRandomFloat(ceil(marchPos.y * 58)), GenerateHashedRandomFloat(ceil(marchPos.z * 120)), GenerateHashedRandomFloat(ceil(marchPos.x * 20))) * 2 - 1) * _JitterSize;
            float3 uvw = GetUVWInAABB(sampleMarchPos, _FluidCenter, _FluidSize);
            half4 density = SAMPLE_TEXTURE3D(_GasVelocity, sampler_GasVelocity, uvw);
            densityAttenuationAlongCamRay *= exp(-density * length(marchStep) * _DensityMultiply);

            int step2LightSteps = 5;
            float maxOfTMinLight;
            float minOfTMaxLight;
            IntersectAABB(sampleMarchPos, lightDir, _FluidCenter, _FluidSize, maxOfTMinLight, minOfTMaxLight);
            float3 lightMarchPos = sampleMarchPos;
            float3 lightMarchEnd = sampleMarchPos + lightDir * minOfTMaxLight;
            float3 lightStep = (lightMarchEnd - lightMarchPos) / step2LightSteps;
            float3 densityAlongLight = 0;
            for (int step2LightStep = 0; step2LightStep < step2LightSteps; step2LightStep++)
            {
                lightMarchPos += lightStep;
                float3 sampleLightPos = lightMarchPos + (float3(GenerateHashedRandomFloat(ceil(marchPos.y * 58)), GenerateHashedRandomFloat(ceil(marchPos.z * 120)), GenerateHashedRandomFloat(ceil(marchPos.x * 20))) * 2 - 1) * _JitterSize;
                float3 lightUVW = GetUVWInAABB(sampleLightPos, _FluidCenter, _FluidSize);
                half4 lightDensity = SAMPLE_TEXTURE3D(_GasVelocity, sampler_GasVelocity, lightUVW);
                densityAlongLight += lightDensity * length(lightStep) * _DensityMultiply;
            }
            float3 luminance = lightColor * exp(-densityAlongLight) * density;
            color.xyz += luminance * densityAttenuationAlongCamRay;
        }
        float mie = MieScatteringFuncHG(lightDir, -rayDirWS);
        // color.xyz = 1 - length(densityAttenuationAlongCamRay);
        color.w = saturate(1 - length(densityAttenuationAlongCamRay));

        return color;
        return densityAttenuationAlongCamRay.x;
        return intersect ? 1 : 0;
    }
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeLine"="UniversalRenderPipeline" //用于指明使用URP来渲染  
        }
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }
    }
}