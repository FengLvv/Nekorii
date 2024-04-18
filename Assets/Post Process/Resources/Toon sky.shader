Shader "URP/Sky"
{
    Properties //着色器的输入 
    {
        _DayBottomColor("Day Bottom Color", Color) = (0.5,0.5,0.5,1)
        _DayMidColor("Day Mid Color", Color) = (0.5,0.5,0.5,1)
        _DayTopColor("Day Top Color", Color) = (0.5,0.5,0.5,1)
        _NightBottomColor("Night Bottom Color", Color) = (0.5,0.5,0.5,1)
        _NightTopColor("Night Top Color", Color) = (0.5,0.5,0.5,1)
        _DayHorColor("Day Hor Color", Color) = (0.5,0.5,0.5,1)

        _NightHorWidth("Night Hor Width", Range(0, 1)) = 0.5
        _DayHorWidth("Day Hor Width", Range(0, 1)) = 0.5
        _NightHorStrenth("Night Hor Strenth", Range(0, 1)) = 0.5
        _DayHorStrenth("Day Hor Strenth", Range(0, 1)) = 0.5

        _NightHorColor("Night Hor Color", Color) = (0.5,0.5,0.5,1)
    }


    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

    CBUFFER_START(UnityPerMaterial)
        float4 _DayBottomColor;
        float4 _DayMidColor;
        float4 _DayTopColor;
        float4 _NightBottomColor;
        float4 _NightTopColor;
        float4 _DayHorColor;

        float _NightHorWidth;
        float _DayHorWidth;
        float _NightHorStrenth;
        float _DayHorStrenth;

        float4 _NightHorColor;

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
    };

    Varyings vert(Attributes v)
    {
        Varyings o;
        o.positionCS = TransformObjectToHClip(v.positionOS);
        o.uv = v.uv;
        o.vertexColor = v.vertexColor;
        return o;
    }

    half4 frag(Varyings i):SV_Target
    {
        Light mainLight = GetMainLight();
        float3 lightDir = mainLight.direction;
        float verticalPos = i.uv.x * 0.5 + 0.5;

        float sunNightStep = smoothstep(-0.3, 0.25, lightDir.x);
        //DAY NIGHT
        float3 gradientDay = lerp(_DayBottomColor, _DayMidColor, saturate(i.uv.y)) * step(0, -i.uv.y)
                             + lerp(_DayMidColor, _DayTopColor, saturate(i.uv.y)) * step(0, i.uv.y);
        float3 gradientNight = lerp(_NightBottomColor, _NightTopColor, verticalPos);
        float3 skyGradients = lerp(gradientNight, gradientDay, sunNightStep);

        //HORIZONTAL
        float horWidth = lerp(_NightHorWidth, _DayHorWidth, sunNightStep);
        float horStrenth = lerp(_NightHorStrenth, _DayHorStrenth, sunNightStep);
        float horLineMask = smoothstep(-horWidth, 0, i.uv.y) * smoothstep(-horWidth, 0, -i.uv.y);
        float3 horLineGradients = lerp(skyGradients, _DayHorColor, sunNightStep);

        return half4(horLineGradients, 1.0);
        return half4(horLineGradients, 1.0);
    }
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Background"
            "UniversalMaterialType" = "Unlit"
            "Queue" = "Background"
            "DisableBatching" = "True"
            "ShaderGraphTargetId" = "UniversalUnlitSubTarget"
            "PreviewType" = "Skybox"
        }
 

        Pass
        {
            Cull Back
            Blend Off
            ZTest LEqual
            ZWrite Off
            ZClip False
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }
    }
}