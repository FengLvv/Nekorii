Shader "Custom/GasSample"
{
    Properties //着色器的输入    
    {
        _ZValue("ZValue", Range(0, 1)) = 0.5
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
    #include  "../Include/Volume Calculation Function.hlsl"

    CBUFFER_START(UnityPerMaterial)
    CBUFFER_END

    float _ZValue;

    TEXTURE3D(_GasVelocity); //贴图采样    
    SAMPLER(sampler_GasVelocity);

    struct AttributesGas //顶点着色器  
    {
        float4 positionOS: POSITION;
        float2 uv : TEXCOORD0;
    };

    struct VaryingsGas //片元着色器  
    {
        float4 positionCS: SV_POSITION;
        float2 uv: TEXCOORD0;
    };

    VaryingsGas vert(AttributesGas v)
    {
        VaryingsGas o;
        o.positionCS = TransformObjectToHClip(v.positionOS);
        o.uv = v.uv;
        return o;
    }
    half4 frag(VaryingsGas i) : SV_Target
    {
        half4 col = SAMPLE_TEXTURE3D(_GasVelocity, sampler_GasVelocity, float3(i.uv,_ZValue));
        return col;
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
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }
    }
}