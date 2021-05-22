Shader "URP/Fog/Bump"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [NoScaleOffset] _BumpMap ("Normalmap", 2D) = "bump" {}
    }
    SubShader
    {
        Tags 
		{ 
            "RenderPipeline"="UniversalPipeline"
            "RenderType" = "Opaque"
		}

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Header.cginc"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_BumpMap);
        SAMPLER(sampler_BumpMap);

        struct a2f
        {
            float4 positionOS : POSITION;
            float2 texcoord : TEXCOORD0;
            float3 normalOS : NORMAL;
            float4 tangentOS : TANGENT;
        };

        struct v2f
        {
            float4 positionCS : SV_POSITION;
            float2 texcoord : TEXCOORD0;
            // UNITY_FOG_COORDS(1)
            float3 positionWS : TEXCOORD1;
            float3 normalWS : TEXCOORD2;
            float3 tangentWS : TEXCOORD3;
            float3 bitangentWS : TEXCOORD4;
            float4 screenPos : TEXCOORD5;
        };
        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature _FOG_ON

            v2f vert(a2f i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord = TRANSFORM_TEX(i.texcoord,_MainTex);
                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                
                o.normalWS = normalize(TransformObjectToWorldNormal(i.normalOS));
                o.tangentWS= normalize(TransformObjectToWorld(i.tangentOS.xyz));
                o.bitangentWS = cross(o.normalWS,o.tangentWS)*i.tangentOS.w;
                o.screenPos = ComputeScreenPos(o.positionCS);

                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                half4 nortex = SAMPLE_TEXTURE2D(_BumpMap,sampler_BumpMap,i.texcoord);
                half3 normalTS = UnpackNormal(nortex);
                half3x3 TBN = {i.tangentWS,i.bitangentWS,i.normalWS};
                half3 norWS = mul(normalTS, TBN);

                Light myLight = GetMainLight();
                half halfLambot = dot(norWS,normalize(myLight.direction))*0.5+0.5;

                half4 col = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord);
                #ifdef _FOG_ON
                    col.xyz = ExponentialHeightFog(col.xyz, i.positionWS);
                #endif
                    return half4(col.xyz,1);
            }
            ENDHLSL
        }
    }
}
