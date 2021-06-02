Shader "URP/ColorAdjustment" 
{
    Properties 
    {
        //贴图
        _MainTex ("MainTex (RGB)", 2D) = "white" {}
        _BaseColor("Base Color",Color) = (1, 1, 1, 1)
        //Hue的值范围为0-359. 其他两个为0-1 ,这里我们设置到3，因为乘以3后 都不一定能到超过.
        _Hue ("Hue", float) = 0 // 色相
        _Saturation ("Saturation", float) = 1 //饱和
        _Value ("Value", float) = 1 //明度
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

            Lighting Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag


            //RGB to HSV
            float3 RGBConvertToHSV(float3 rgb)
            {
                float R = rgb.x,G = rgb.y,B = rgb.z;
                float3 hsv;
                float max1=max(R,max(G,B));
                float min1=min(R,min(G,B));
                if (R == max1) 
                {
                    hsv.x = (G-B)/(max1-min1);
                }
                if (G == max1) 
                {
                    hsv.x = 2 + (B-R)/(max1-min1);
                    }
                if (B == max1) 
                {
                    hsv.x = 4 + (R-G)/(max1-min1);
                    }
                hsv.x = hsv.x * 60.0;   
                if (hsv.x < 0) 
                    hsv.x = hsv.x + 360;
                hsv.z=max1;
                hsv.y=(max1-min1)/max1;
                return hsv;
            }

            //HSV to RGB
            float3 HSVConvertToRGB(float3 hsv)
            {
                float R,G,B;
                //float3 rgb;
                if( hsv.y == 0 )
                {
                    R=G=B=hsv.z;
                }
                else
                {
                    hsv.x = hsv.x/60.0; 
                    int i = (int)hsv.x;
                    float f = hsv.x - (float)i;
                    float a = hsv.z * ( 1 - hsv.y );
                    float b = hsv.z * ( 1 - hsv.y * f );
                    float c = hsv.z * ( 1 - hsv.y * (1 - f ) );
                    switch(i)
                    {
                        case 0: R = hsv.z; G = c; B = a;
                            break;
                        case 1: R = b; G = hsv.z; B = a; 
                            break;
                        case 2: R = a; G = hsv.z; B = c; 
                            break;
                        case 3: R = a; G = b; B = hsv.z; 
                            break;
                        case 4: R = c; G = a; B = hsv.z; 
                            break;
                        default: R = hsv.z; G = a; B = b; 
                            break;
                    }
                }
                return float3(R,G,B);
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
                half4 original = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord);    //获取贴图原始颜色

                //half gray = original.r * 0.3 + original.g * 0.59 + original.b * 0.11;

                float3 colorHSV;    
                //colorHSV.xyz = RGBConvertToHSV(original.rgb);   //转换为HSV

                //colorHSV.x = _Hue; //调整偏移Hue值
                //colorHSV.y = _Saturation;
                //colorHSV.z *= _Value;

                original.rgb = HSVConvertToRGB(original.rgb);   //将调整后的HSV，转换为RGB颜色

                return original;
            }
            ENDHLSL
        } 
    }
}
