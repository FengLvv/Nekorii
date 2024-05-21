Shader "Aurora/AuroraSky"
{
    Properties
    {
        [Header(Sky Setting)]
        _Color1 ("Top Color", Color) = (1, 1, 1, 0)
        _Color2 ("Horizon Color", Color) = (1, 1, 1, 0)
        _Color3 ("Bottom Color", Color) = (1, 1, 1, 0)
        _Exponent1 ("Exponent Factor for Top Half", Float) = 1.0
        _Exponent2 ("Exponent Factor for Bottom Half", Float) = 1.0
        _Intensity ("Intensity Amplifier", Float) = 1.0


        [Header(Star Setting)]
        [HDR]_StarColor ("Star Color", Color) = (1,1,1,0)
        _StarIntensity("Star Intensity", Range(0,1)) = 0.5
        _StarSpeed("Star Speed", Range(0,1)) = 0.5

        [Header(Cloud Setting)]
        [HDR]_CloudColor ("Cloud Color", Color) = (1,1,1,0)
        _CloudIntensity("Cloud Intensity", Range(0,1)) = 0.5
        _CloudSpeed("CloudSpeed", Range(0,1)) = 0.5

        [Header(Aurora Setting)]
        [HDR]_AuroraColor ("Aurora Color", Color) = (1,1,1,0)
        _AuroraIntensity("Aurora Intensity", Range(0,1)) = 0.5
        _AuroraSpeed("AuroraSpeed", Range(0,1)) = 0.5
        _SurAuroraColFactor("Sur Aurora Color Factor", Range(0,1)) = 0.5

        [Header(Envirment Setting)]
        [HDR]_MountainColor ("Mountain Color", Color) = (1,1,1,0)
        _MountainFactor("Mountain Factor", Range(0,1)) = 0.5
        _MountainHeight("Mountain Height", Range(0,2)) = 0.5

    }

    CGINCLUDE

    #include "UnityCG.cginc"

    struct appdata
    {
        float4 position : POSITION;
        float3 texcoord : TEXCOORD0;
        float3 normal : NORMAL;
    };
    
    struct v2f
    {
        float4 position : SV_POSITION;
        float3 texcoord : TEXCOORD0;
        float3 normal : TEXCOORD1;
    };
    
    // 环境背景颜色
    half4 _Color1;
    half4 _Color2;
    half4 _Color3;
    half _Intensity;
    half _Exponent1;
    half _Exponent2;


    //星星 
    half4 _StarColor;
    half _StarIntensity;
    half _StarSpeed;

    // 云
    half4 _CloudColor;
    half _CloudIntensity;
    half _CloudSpeed;

    // 极光
    half4 _AuroraColor;
    half _AuroraIntensity;
    half _AuroraSpeed;
    half _SurAuroraColFactor;
    
    // 远景山
    half4 _MountainColor;
    float _MountainFactor;
    half _MountainHeight;


    
    v2f vert (appdata v)
    {
        v2f o;
        o.position = UnityObjectToClipPos (v.position);
        o.texcoord = v.texcoord;
        o.normal = v.normal;
        return o;
    }
    
    




    /**************带状极光***************/

    // 旋转矩阵
    float2x2 RotateMatrix(float a){
        float c = cos(a);
        float s = sin(a);
        return float2x2(c,s,-s,c);
    }

    float tri(float x){
        return clamp(abs(frac(x)-0.5),0.01,0.49);
    }

    float2 tri2(float2 p){
        return float2(tri(p.x)+tri(p.y),tri(p.y+tri(p.x)));
    }

    // 极光噪声
    float SurAuroraNoise(float2 pos)
    {
        float intensity=1.8;
        float size=2.5;
    	float rz = 0;
        pos = mul(RotateMatrix(pos.x*0.06),pos);
        float2 bp = pos;
    	for (int i=0; i<5; i++)
    	{
            float2 dg = tri2(bp*1.85)*.75;
            dg = mul(RotateMatrix(_Time.y*_AuroraSpeed),dg);
            pos -= dg/size;

            bp *= 1.3;
            size *= .45;
            intensity *= .42;
    		pos *= 1.21 + (rz-1.0)*.02;

            rz += tri(pos.x+tri(pos.y))*intensity;
            pos = mul(-float2x2(0.95534, 0.29552, -0.29552, 0.95534),pos);
    	}
        return clamp(1.0/pow(rz*29., 1.3),0,0.55);
    }

    float SurHash(float2 n){
         return frac(sin(dot(n, float2(12.9898, 4.1414))) * 43758.5453); 
    }

    float4 SurAurora(float3 pos,float3 ro)
    {
        float4 col = float4(0,0,0,0);
        float4 avgCol = float4(0,0,0,0);

        // 逐层
        for(int i=0;i<30;i++)
        {
            // 坐标
            float of = 0.006*SurHash(pos.xy)*smoothstep(0,15, i);       
            float pt = ((0.8+pow(i,1.4)*0.002)-ro.y)/(pos.y*2.0+0.8);
            pt -= of;
        	float3 bpos = ro + pt*pos;
            float2 p = bpos.zx;

            // 颜色
            float noise = SurAuroraNoise(p);
            float4 col2 = float4(0,0,0, noise);
            col2.rgb = (sin(1.0-float3(2.15,-.5, 1.2)+i*_SurAuroraColFactor*0.1)*0.8+0.5)*noise;
            avgCol =  lerp(avgCol, col2, 0.5);
            col += avgCol*exp2(-i*0.065 - 2.5)*smoothstep(0.,5., i);

        }

        col *= (clamp(pos.y*15.+.4,0.,1.));

        return col*1.8;
    }


    half4 frag (v2f i) : COLOR
    {
        // return fixed4(SurAuroraNoise(i.texcoord.xy),SurAuroraNoise(i.texcoord.xy),SurAuroraNoise(i.texcoord.xy),1);
        // 底色
        float p = normalize(i.texcoord).y;
        float p1 = 1.0f - pow (min (1.0f, 1.0f - p), _Exponent1);
        float p3 = 1.0f - pow (min (1.0f, 1.0f + p), _Exponent2);
        float p2 = 1.0f - p1 - p3;
        int reflection = i.texcoord.y < 0 ? -1 : 1;


        //带状极光
        float4 surAuroraCol = smoothstep(0.0,1.5,SurAurora(
                                                    float3(i.texcoord.x,abs(i.texcoord.y),i.texcoord.z),
                                                    float3(0,0,-6.7)
                                                    )) + (reflection-1)*-0.2*0.5;

        
        //混合
        float4 skyCol = (_Color1 * p1 + _Color2 * p2 + _Color3 * p3) * _Intensity;
        skyCol = skyCol*(1 - surAuroraCol.a) + surAuroraCol * surAuroraCol.a;

        return skyCol;

    }

    ENDCG

    SubShader
    {
        Tags { "RenderType"="Background" "Queue"="Background" }
        Pass
        {
            ZWrite Off
            Cull Off
            Fog { Mode Off }
            CGPROGRAM
            #pragma fragmentoption ARB_precision_hint_fastest
            #pragma vertex vert
            #pragma fragment frag
            ENDCG
        }
    } 
}