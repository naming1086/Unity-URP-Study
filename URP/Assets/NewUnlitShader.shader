Shader "Built-in/Unlit"
{
    /*一个基础的着色器*/
    Properties
    {
        _MainTex ("Base Texture", 2D) = "white" {} 
        _BaseColor("Base Color",Color)=(1,1,1,1)
    }
        
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        
		CGINCLUDE    
		float4 _BaseColor;
		float4 _MainTex_ST;
		sampler2D _MainTex;

		struct a2v
		{
			float4 positionOS : POSITION;
			float2 texcoord : TEXCOORD;
		};

		struct v2f
		{
			float4 positionCS : SV_POSITION;
			float2 texcoord : TEXCOORD;
		};

		ENDCG

        Pass
        {
            CGPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
			
			#include "UnityCG.cginc"
			
			v2f vert(a2v i)
			{
				v2f o;
				o.positionCS = UnityObjectToClipPos(i.positionOS);
				o.texcoord = TRANSFORM_TEX(i.texcoord, _MainTex);
				return o;
    		}
    
			half4 frag(v2f i): SV_Target
			{
				half4 mainTex = tex2D(_MainTex, i.texcoord);
				return _BaseColor * mainTex;
			}
			
            ENDCG         
        }
    }
}
