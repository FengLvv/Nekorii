Shader "URP/Sky"
{
    Properties //着色器的输入 
    {
        _StarSkyTex("Star Sky Tex", Cube) = "white" {}

        _SkyHeight("Sky Height", Range(-1, 1)) = 0.1
        _SkyHorizonRange("Sky Horizon Range", Range(0, 1)) = 0.2

        [Header(Day Color)]
        _DayBottomColor("Day Bottom Color", Color) = (0.5,0.5,0.5,1)
        _DayMidColor("Day Mid Color", Color) = (0.5,0.5,0.5,1)
        _DayTopColor("Day Top Color", Color) = (0.5,0.5,0.5,1)
        [Header(Night Color)]
        _NightBottomColor("Night Bottom Color", Color) = (0.5,0.5,0.5,1)
        _NightMidColor("Night Mid Color", Color) = (0.5,0.5,0.5,1)
        _NightTopColor("Night Top Color", Color) = (0.5,0.5,0.5,1)
        _DayHorColor("Day Hor Color", Color) = (0.5,0.5,0.5,1)

        _NightHorWidth("Night Hor Width", Range(0, 1)) = 0.5
        _DayHorWidth("Day Hor Width", Range(0, 1)) = 0.5
        _NightHorStrenth("Night Hor Strenth", Range(0, 1)) = 0.5
        _DayHorStrenth("Day Hor Strenth", Range(0, 1)) = 0.5

        _NightHorColor("Night Hor Color", Color) = (0.5,0.5,0.5,1)

        [Header(Aurora)]
        _Intensity("Intensity", Range(0, 1)) = 0.5
        _AuroraSpeed("Aurora Speed", Range(0, 1)) = 0.5
        _SurAuroraColFactor("Sur Aurora Col Factor", Range(0, 1)) = 0.5

    }


    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

    CBUFFER_START(UnityPerMaterial)
        float _SkyHeight;
        float _SkyHorizonRange;

        float4 _LightPosition;

        float4 _DayBottomColor;
        float4 _DayMidColor;
        float4 _DayTopColor;
        float4 _NightBottomColor;
        float4 _NightMidColor;
        float4 _NightTopColor;
        float4 _DayHorColor;

        float _NightHorWidth;
        float _DayHorWidth;
        float _NightHorStrenth;
        float _DayHorStrenth;

        float4 _NightHorColor;


        float _AuroraSpeed;
        float _SurAuroraColFactor;
        float _Intensity;

    CBUFFER_END

    TEXTURECUBE(_StarSkyTex); //贴图声明
    SAMPLER(sampler_StarSkyTex);

    TEXTURE2D(_BaseMap); //贴图采样  
    SAMPLER(sampler_BaseMap);

    struct Attributes //顶点着色器
    {
        float4 color: COLOR;
        float4 positionOS: POSITION;
        float3 normalOS: TANGENT;
        half4 vertexColor: COLOR;
        float3 uv : TEXCOORD0;
    };

    struct Varyings //片元着色器
    {
        float4 positionCS: SV_POSITION;
        float3 uv: TEXCOORD0;
        half4 vertexColor: COLOR;
        float3 posWS: TEXCOORD1;
    };



    // 旋转矩阵
    float2x2 RotateMatrix(float a)
    {
        float c = cos(a);
        float s = sin(a);
        return float2x2(c, s, -s, c);
    }

    float tri(float x)
    {
        return clamp(abs(frac(x) - 0.5), 0.01, 0.49);
    }

    float2 tri2(float2 p)
    {
        return float2(tri(p.x) + tri(p.y), tri(p.y + tri(p.x)));
    }

    // 极光噪声
    float SurAuroraNoise(float2 pos)
    {
        float intensity = 1.8;
        float size = 2.5;
        float rz = 0;
        pos = mul(RotateMatrix(pos.x * 0.06), pos);
        float2 bp = pos;
        for (int i = 0; i < 5; i++)
        {
            float2 dg = tri2(bp * 1.85) * .75;
            dg = mul(RotateMatrix(_Time.y * _AuroraSpeed), dg);
            pos -= dg / size;

            bp *= 1.3;
            size *= .45;
            intensity *= .42;
            pos *= 1.21 + (rz - 1.0) * .02;

            rz += tri(pos.x + tri(pos.y)) * intensity;
            pos = mul(-float2x2(0.95534, 0.29552, -0.29552, 0.95534), pos);
        }
        return clamp(1.0 / pow(rz * 29., 1.3), 0, 0.55);
    }

    float SurHash(float2 n)
    {
        return frac(sin(dot(n, float2(12.9898, 4.1414))) * 43758.5453);
    }

    float4 SurAurora(float3 pos, float3 ro)
    {
        float4 col = float4(0, 0, 0, 0);
        float4 avgCol = float4(0, 0, 0, 0);

        // 逐层
        for (int i = 0; i < 30; i++)
        {
            // 坐标
            float of = 0.006 * SurHash(pos.xy) * smoothstep(0, 15, i);
            float pt = ((0.8 + pow(i, 1.4) * 0.002) - ro.y) / (pos.y * 2.0 + 0.8);
            pt -= of;
            float3 bpos = ro + pt * pos;
            float2 p = bpos.zx;

            // 颜色
            float noise = SurAuroraNoise(p);
            float4 col2 = float4(0, 0, 0, noise);
            col2.rgb = (sin(1.0 - float3(2.15, -.5, 1.2) + i * _SurAuroraColFactor * 0.1) * 0.8 + 0.5) * noise;
            avgCol = lerp(avgCol, col2, 0.5);
            col += avgCol * exp2(-i * 0.065 - 2.5) * smoothstep(0., 5., i);
        }

        col *= (clamp(pos.y * 15. + .4, 0., 1.));

        return col * 1.8;
    }



    Varyings vert(Attributes v)
    {
        Varyings o;
        o.positionCS = TransformObjectToHClip(v.positionOS);
        o.posWS = TransformObjectToWorld(v.positionOS);
        o.uv = v.uv;
        o.vertexColor = v.vertexColor;
        return o;
    }

    half4 frag(Varyings i):SV_Target
    {
        Light mainLight = GetMainLight();
        float3 lightDir = mainLight.direction;
        float verticalPos = i.uv.x * 0.5 + 0.5;
        float3 viewDir = GetWorldSpaceNormalizeViewDir(i.posWS);
        float fresnel = dot(viewDir, float3(0, 1, 0));
        fresnel = 1 - fresnel;
        fresnel = fresnel * fresnel * fresnel * fresnel * fresnel * fresnel;
        float sunNightStep = smoothstep(-0.3, 0.25, lightDir.y);

        //带状极光
        float4 au = SurAurora(
            float3(i.uv.x, abs(i.uv.y), i.uv.z),
            float3(0, 0, 7)
        );
        float4 surAuroraCol = smoothstep(0.0, 1.5, au);
        surAuroraCol *= surAuroraCol.a * fresnel;

        //星空
        float3 cubeDir = float3(viewDir.x, i.posWS.y < 0 ? -viewDir.y : viewDir.y, viewDir.z);
        float3 nightStar = SAMPLE_TEXTURECUBE(_StarSkyTex, sampler_StarSkyTex, cubeDir).rgb * fresnel;


        //DAY NIGHT
        float horizonTop = _SkyHeight + _SkyHorizonRange;
        float horizonBottom = _SkyHeight - _SkyHorizonRange;

        float horizonMask = step(horizonTop, i.uv.y);
        float horizonBottomMask = smoothstep(horizonBottom, horizonTop, i.uv.y);
        float horizonTopMask = smoothstep(horizonTop, 1, i.uv.y);

        float3 dayBottomColor = lerp(_DayBottomColor, _DayMidColor, horizonBottomMask);
        float3 dayTopColor = lerp(_DayMidColor, _DayTopColor, horizonTopMask);
        float3 dayColor = lerp(dayBottomColor, dayTopColor, horizonMask);

        float3 nightBottomColor = lerp(_NightBottomColor, _NightMidColor, horizonBottomMask);
        float3 nightTopColor = lerp(_NightMidColor, _NightTopColor, horizonTopMask);
        float3 nightColor = lerp(nightBottomColor, nightTopColor, horizonMask);
        nightColor += nightStar;
        nightColor += surAuroraCol.rgb;


        float3 skyColor = lerp(nightColor, dayColor, sunNightStep);

        //HORIZONTAL
        float horWidth = lerp(_NightHorWidth, _DayHorWidth, sunNightStep);
        float horStrenth = lerp(_NightHorStrenth, _DayHorStrenth, sunNightStep);
        float horLineMask = smoothstep(-horWidth, 0, i.uv.y) * smoothstep(-horWidth, 0, -i.uv.y);
        float3 horLineGradients = lerp(_NightHorColor, _DayHorColor, sunNightStep);
        float4 a = lerp(_DayBottomColor, _DayMidColor, saturate(i.uv.y));

        return half4(skyColor, 1.0);
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