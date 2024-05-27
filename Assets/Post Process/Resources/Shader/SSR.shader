Shader "Custom/PostProcess/SSR"
{
    Properties {}


    SubShader
    {
        Tags
        {
            "LightMode" = "UniversalForward"
            "RenderType"="Opaque"
            "RenderPipeLine"="UniversalRenderPipeline" //用于指明使用URP来渲染
        }
        HLSLINCLUDE
        #include "../Include/SSR.hlsl"
        half4 fragBlit(VaryingsVL i) : SV_Target
        {
            half4 blit = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, i.uv);
            return blit;
        }
        ENDHLSL

        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            HLSLPROGRAM
            #pragma vertex vertSSR
            // #pragma fragment fragSSR
            // #pragma fragment fragSSRDDA
             // #pragma fragment fragSSRDDABinary
            #pragma fragment fragSSRDDAHIZ
        
            ENDHLSL
        }
        Pass
        {
            Name "drawSSR"
            ZTest LEqual
            ZWrite On
            Tags
            {
                "LightMode" = "DrawSSR"
            }
//            Blend one one
            HLSLPROGRAM
            #pragma vertex vertDrawSSR
            #pragma fragment fragRenderReflection       
            ENDHLSL
        }

    }
}