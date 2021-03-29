using System.IO;
using UnityEditor;
using UnityEngine;

namespace Akari
{
    public class NoiseGenerator : EditorWindow
    {
        int x = 128;
        int y = 128;
        string texName = "New Noise";
        int scale = 1;
        int step = 1;

        [MenuItem("Tools/生成噪声图")]
        static void Init()
        {
            EditorWindow.GetWindow(typeof(NoiseGenerator)).Show();
        }

        void GenerateNoiseImage(int x, int y)
        {
            int size = Mathf.Min(x, y);
            Texture2D tex = new Texture2D(x, y, TextureFormat.RGB24, false);
            Color[] pixel = new Color[x * y];
            for (int i = 0; i < x; i = i + step)
            {
                pixel[i] = new Color(1, 1, 1);
            }
            for (int i = 0; i < x; i = i + step)
            {
                for (int j = 0; j < x; j = j + step)
                {
                    float sample = Mathf.PerlinNoise((float)i / x * scale, (float)j / y * scale);
                    sample = Mathf.Clamp(sample, 0f, 1f);
                    pixel[i * size + j] = new Color(sample, sample, sample);
                }
            }
            tex.SetPixels(pixel);
            tex.Apply();

            string path = System.Environment.CurrentDirectory + "\\Assets\\NoiseGenerator\\" + texName + ".png";

            if (File.Exists(path))
            {
                File.Delete(path);
            }

            File.WriteAllBytes(path, tex.EncodeToPNG());
            EditorUtility.DisplayDialog("成功", "噪声图\"" + texName + "\"" + "已在Assets目录下生成！", "确定", "取消");
            AssetDatabase.Refresh();
        }

        private void OnGUI()
        {
            EditorGUILayout.BeginHorizontal();
            texName = EditorGUILayout.TextField("图片名: ", texName);
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.BeginHorizontal();
            y = EditorGUILayout.IntField("图片长: ", y);
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.BeginHorizontal();
            x = EditorGUILayout.IntField("图片宽: ", x);
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.BeginHorizontal();
            scale = EditorGUILayout.IntField("Scale: ", scale);
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.BeginHorizontal();
            step = EditorGUILayout.IntField("Step: ", step);
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.BeginHorizontal();
            if (GUILayout.Button("生成"))
            {
                if (x < 1 || y < 1)
                {
                    Debug.LogError("图片长或宽必须大于1");
                    return;
                }
                if (texName == null || texName.Length < 1)
                {
                    Debug.LogError("请为图片命名");
                    return;
                }
                if (step >= x || step >= y)
                {
                    Debug.LogError("密度不能超过图片的长或宽");
                    return;
                }
                else if (step < 1)
                {
                    step = 1;
                }
                GenerateNoiseImage(x, y);
            }
            EditorGUILayout.EndHorizontal();
        }
    }
}
