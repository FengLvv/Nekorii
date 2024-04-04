Shader "Custom/PostProcess/VolumeLight"
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
        #include "Volume Light.hlsl"
        half4 fragBlit(VaryingsVL i) : SV_Target
        {
            half4 blit = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, i.uv);
            return blit;
        }
        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vertVL
            #pragma fragment fragVL
            ENDHLSL
        }
        Pass
        {
            Blend One One
            HLSLPROGRAM
            #pragma vertex vertVL
            #pragma fragment fragBlit
            ENDHLSL
        }
    }
}