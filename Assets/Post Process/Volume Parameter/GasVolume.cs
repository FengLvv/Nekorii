using System;
using System.Diagnostics;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu( "Custom/GasVolume" )]
[SupportedOnRenderPipeline]
public class GasVolume : VolumeComponent, IPostProcessComponent {
	//定义shader要用的参数
	public Vector3Parameter renderPos = new Vector3Parameter( new Vector3( 0, 0, 0 ) );
	public Vector3Parameter renderSize = new Vector3Parameter( new Vector3( 5, 5, 5 ) );


	[ExecuteAlways]
	public bool IsActive() {
		return true;
	}
	public bool IsTileCompatible() {
		return false;
	}
}