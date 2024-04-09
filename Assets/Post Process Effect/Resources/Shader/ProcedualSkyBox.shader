Shader "Custom/Sky/Atmosphere"
{
    Properties {}


    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeLine"="UniversalRenderPipeline" //用于指明使用URP来渲染
        }
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "../Include/Volume Calculation Function.hlsl"


        struct AttributesSky {
            float4 posOS : POSITION;
            float2 uv : TEXCOORD0;
        };

        struct VaryingsSky {
            float4 posCS : SV_POSITION;
            float3 posWS : TEXCOORD1;

            float2 uv : TEXCOORD0;
        };

        VaryingsSky vert(AttributesSky IN)
        {
            VaryingsSky OUT;
            VertexPositionInputs pos = GetVertexPositionInputs(IN.posOS);
            OUT.posCS = pos.positionCS;
            OUT.posWS = pos.positionWS;
            OUT.uv = IN.uv;
            return OUT;
        }

        half4 frag(VaryingsSky IN) : SV_Target
        {
            float3 cameraPosWS = _WorldSpaceCameraPos;
            float3 dir = normalize(IN.posWS - cameraPosWS);

            return float4(IN.posWS, 1);
        }
        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }

    }
}