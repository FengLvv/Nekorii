Shader "Custom/PostProcess/Blur"
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
        #include "Postprocess Blur.hlsl"
        half4 fragBlit(Varyings i) : SV_Target
        {
            half4 blit = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, i.texcoord);
            return blit;
        }
        ENDHLSL

        // Pass 0 : Gaussian Blur Horizontal
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vertGaussianBlurH
            #pragma fragment fragGaussianBlur
            ENDHLSL
        }

        // Pass 1 : Gaussian Blur Vertical
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vertGaussianBlurV
            #pragma fragment fragGaussianBlur
            ENDHLSL
        }

        // Pass 2 : Bilateral Blur Horizontal
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vertBilateralBlurH
            #pragma fragment fragBilateralBlur
            ENDHLSL
        }

        // Pass 3 : Bilateral Blur Vertical
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vertBilateralBlurV
            #pragma fragment fragBilateralBlur
            ENDHLSL
        }
    }
}