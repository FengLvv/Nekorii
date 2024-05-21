Shader "Custom/SeaSSR"
{
    Properties
    {
        [Normal] _Normal("Normal", 2D) = "white" {}
        [HDR]_TrailColor("Trail Color Fast", Color) = (1,1,1,1)

    }

    HLSLINCLUDE
    #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

    // #pragma multi_compile_fragment _ _SHADOWS_SOFT
    #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
    #pragma multi_compile _ SHADOWS_SHADOWMASK
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Assets/AnyTrail/AnyTrailShaderInclude.hlsl"

    TEXTURE2D(_Normal);
    SAMPLER(sampler_Normal);
    CBUFFER_START(UnityPerMaterial)
        float4 _Normal_ST;
        float4 _TrailColor;

    CBUFFER_END


    struct Attributes //顶点着色器
    {
        float4 positionOS: POSITION;
        float3 normalOS: NORMAL;
        float4 tangengOS: TANGENT;
        float2 uv: TEXCOORD0;
    };

    struct Varyings //片元着色器
    {
        float4 positionCS: SV_POSITION;
        float3 normalWS : NORMAL;
        float3 positionWS : TEXCOORD1;
        float4 shadowCoord : TEXCOORD4;
        float3 tangentWS : TANGENT;
        float3 bitangentWS : BITANGENT;
        float2 uv : TEXCOORD0;
    };

    Varyings vert(Attributes v)
    {
        Varyings o;
        VertexPositionInputs pos = GetVertexPositionInputs(v.positionOS);
        o.shadowCoord = GetShadowCoord(pos);
        o.positionCS = pos.positionCS;
        o.positionWS = pos.positionWS;
        VertexNormalInputs normal = GetVertexNormalInputs(v.normalOS, v.tangengOS);
        o.tangentWS = normal.tangentWS;
        o.bitangentWS = normal.bitangentWS;
        o.normalWS = normal.normalWS;

        o.uv = v.uv;

        return o;
    }

    half4 frag(Varyings i) : SV_Target /* 注意在HLSL中，fixed4类型变成了half4类型*/
    {
        half shadow = MainLightRealtimeShadow(i.shadowCoord);

        half cascadeIndex = ComputeCascadeIndex(i.positionWS);
        float4 shadowCoord = mul(_MainLightWorldToShadow[cascadeIndex], float4(i.positionWS, 1.0));
        ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
        half4 shadowParams = GetMainLightShadowParams();
        shadow = SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowCoord, shadowSamplingData, shadowParams, false);

        float colora = length(SampleAnyTrailFluid(i.positionWS));
        colora = saturate(lerp(0, colora, smoothstep(0.01, 0.1, colora)));
        float4 colorN = lerp(0, _TrailColor, colora);

        float4 color = colorN;
        color.xyz *= shadow;
        color.w += 1 - shadow;

        return 0.05;
    }

    half4 fragNormal(Varyings i) : SV_Target
    {
        half3 normal = i.normalWS;
        return half4(normal, 1);
    }
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" //用于指明渲染类型
            "Queue"="Geometry" //用于指明渲染顺序
            "RenderPipeLine"="UniversalRenderPipeline" //用于指明使用URP来渲染      
            "LightMode" = "UniversalForward"
        }

        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            Blend One One
            ZWrite On
            ZTest LEqual
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }
        Pass
        {
            Name "DepthNormals"
            Tags
            {
                "LightMode"="DepthNormals"
            }

            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragNormal

            ENDHLSL
        }
    }
}