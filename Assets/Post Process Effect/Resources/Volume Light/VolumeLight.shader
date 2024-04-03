Shader "Custom/PostProcess/VolumeLight"
{
    Properties {}

    HLSLINCLUDE
    // using cascade shadow map
    #define MAIN_LIGHT_CALCULATE_SHADOWS 
    #define _MAIN_LIGHT_SHADOWS_CASCADE 
    #define RandomJitter(seed) frac((1664525.0 * seed + 1013904223.0) / 4294967296.0)

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

    TEXTURE2D(_BaseMap); //贴图采样  
    SAMPLER(sampler_BaseMap);

    int _MarchSteps;
    int _MaxStepDistance;

    struct VaryingsVL
    {
        float4 positionCS : SV_POSITION;
        float2 uv : TEXCOORD0;
        UNITY_VERTEX_OUTPUT_STEREO
    };

    // input screen uv, output posWS
    float3 GetPixelWorldPosition(float2 uv)
    {
        // sample depth texture
        half4 blitDepth = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, uv);
        // get the 01 depth
        float depthValue = Linear01Depth(blitDepth, _ZBufferParams);

        // get the far point in clip cube far plane
        float3 farPosCS = float3(uv.x * 2 - 1, uv.y * 2 - 1, 1) * _ProjectionParams.z;
        // get the far point in view frumstum
        float3 farPosVS = mul(unity_CameraInvProjection, farPosCS.xyzz).xyz;

        // get posVS of aiming point, transform to world space 
        float3 posVS = farPosVS * depthValue;
        float3 posWS = TransformViewToWorld(posVS);
        return posWS;
    }

    float GetLightAttenuation(float3 position)
    {
        // Transform posWS to shadow coord
        float4 shadowPos = TransformWorldToShadowCoord(position);
        float intensity = MainLightRealtimeShadow(shadowPos);
        return intensity;
    }

    VaryingsVL vertFullScreen(Attributes input)
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

    half4 frag(VaryingsVL i) : SV_Target
    {
        // test
        _MarchSteps = 100;
        _MaxStepDistance = 10;

        // initial position
        float3 initPosWS = GetPixelWorldPosition(i.uv);
        float3 cameraDir = GetWorldSpaceViewDir(initPosWS);
        cameraDir = cameraDir / length(cameraDir) * min(length(cameraDir), _MaxStepDistance);
        float3 marchVector = cameraDir / _MarchSteps;

        // light setting
        float lightIncrement = 1.0 / _MarchSteps;

        // ray marching to camera        
        half shaftLamination = 0;
        float3 marchingPosWS = initPosWS;
        UNITY_LOOP
        for (float i = 0; i < _MarchSteps; i++)
        {
            shaftLamination += GetLightAttenuation(marchingPosWS+ RandomJitter(marchingPosWS)*0.01) * lightIncrement;
            marchingPosWS += marchVector ;
        }

        // half4 blit = float4(0,1,0,1);     
        return float4(shaftLamination.xxx, 1);
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
            HLSLPROGRAM
            #pragma vertex vertFullScreen
            #pragma fragment frag
            ENDHLSL
        }
    }
}