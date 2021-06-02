Shader "URP/HSVRangeShader" 
{
    Properties 
    {
        //��ͼ
        _MainTex ("MainTex (RGB)", 2D) = "white" {}
        _BaseColor("Base Color",Color) = (1, 1, 1, 1)
        //Hue��ֵ��ΧΪ0-359. ��������Ϊ0-1 ,�����������õ�3����Ϊ����3�� ����һ���ܵ�����.
        _Hue ("Hue", Range(0,1)) = 0 // ɫ��
        _Saturation ("Saturation", float) = 1 //����
        _Value ("Value", float) = 1 //����
    }
    SubShader 
    {
        Tags 
        { 
            "RenderType"="Transparent" 
            "RenderPipeline"="UniversalPipeline"
            "Queue"="Transparent"
        }

        Blend SrcAlpha OneMinusSrcAlpha

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        half _Hue;
        half _Saturation;
        half _Value;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        struct a2v
        {
            float4 positionOS : POSITION;
            float2 texcoord : TEXCOORD;
        };

		struct v2f
        {
            float4 positionCS : SV_POSITION;
            float2 texcoord : TEXCOORD0;
        };

        ENDHLSL
        Pass 
        {

            //Lighting Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag


            float3 rgb2hsv(float3 c) 
            {
                float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
                float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
                float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

                float d = q.x - min(q.w, q.y);
                float e = 1.0e-10;
                return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
            }

            float3 hsv2rgb(float3 c) 
            {
                c = float3(c.x, clamp(c.yz, 0.0, 1.0));
                float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
            }  


            v2f vert (a2v i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord = TRANSFORM_TEX(i.texcoord,_MainTex);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                half4 original = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord);    //��ȡ��ͼԭʼ��ɫ

                //half gray = original.r * 0.3 + original.g * 0.59 + original.b * 0.11;

                float3 colorHSV;    
                colorHSV.xyz = rgb2hsv(original.rgb);   //ת��ΪHSV

                colorHSV.x = _Hue; //����ƫ��Hueֵ
                colorHSV.y *= _Saturation;
                colorHSV.z *= _Value;

                original.rgb = hsv2rgb(colorHSV);   //���������HSV��ת��ΪRGB��ɫ

                return original;
            }
            ENDHLSL
        } 
    }
}
