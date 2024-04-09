Shader "Custom/PostProcess/Atmosphere"
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
        #include "../Include/Atmosphere.hlsl"
        half4 fragBlit(VaryingsVL i) : SV_Target
        {
            half4 blit = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, i.uv);
            return blit;
        }
        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vertAtmosphere 
            #pragma fragment fragAtmosphere
            ENDHLSL
        }
        Pass
        {
            Blend One SrcAlpha
            HLSLPROGRAM
            #pragma vertex vertAtmosphere
            #pragma fragment fragBlit
            ENDHLSL
        }
    }
}