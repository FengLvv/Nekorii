Shader "Custom/Sea"
{
    Properties //着色器的输入 
    {
        _BaseMap ("Texture", 2D) = "white" {}
    }


    HLSLINCLUDE
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
    #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
    #pragma multi_compile _ _SHADOWS_SOFT


    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

    CBUFFER_START(UnityPerMaterial)
        //声明变量
        float4 _BaseMap_ST;
    CBUFFER_END

    TEXTURE2D(_BaseMap); //贴图采样  
    SAMPLER(sampler_BaseMap);

    struct Attributes //顶点着色器
    {
        float4 color: COLOR;
        float4 positionOS: POSITION;
        float3 normalOS: TANGENT;
        half4 vertexColor: COLOR;
        float2 uv : TEXCOORD0;
    };

    struct Varyings //片元着色器
    {
        float4 positionCS: SV_POSITION;
        float2 uv: TEXCOORD0;
        half4 vertexColor: COLOR;
        float4 shadowCoord : TEXCOORD4;
    };

    Varyings vert(Attributes v)
    {
        Varyings o;
        o.positionCS = TransformObjectToHClip(v.positionOS);
        o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
        o.vertexColor = v.vertexColor;
        VertexPositionInputs pos = GetVertexPositionInputs(v.positionOS);
        o.shadowCoord = GetShadowCoord(pos);
        o.shadowCoord = TransformWorldToShadowCoord(pos.positionWS);

        return o;
    }

    half4 frag(Varyings i) : SV_Target /* 注意在HLSL中，fixed4类型变成了half4类型*/
    {
        Light mainLight = GetMainLight(i.shadowCoord);
        
        half shadow = mainLight.shadowAttenuation;
        half4 col = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
        half res = lerp(i.vertexColor, col, i.vertexColor.g);
        return shadow;
        return half4(shadow, shadow, shadow, 1.0);
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