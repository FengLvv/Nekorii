using DG.Tweening;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.VFX;

public class SkyController : MonoBehaviour {
	static Color HexColor( string hex ) {
		Color color;
		ColorUtility.TryParseHtmlString( hex, out color );
		return color;
	}


	// 3 for skybox, 1 for canvas
	Dictionary<string, Color[]> Colors = new Dictionary<string, Color[]>(){
		{ "day1", new[]{ HexColor( "#467D8F" ), HexColor( "#87A8B8" ), HexColor( "#C3D2E1" ), new Color(1.0110818f,1.1626690f,1.587772f,1) } },
		{ "night1", new[]{ HexColor( "#194A53" ), HexColor( "#172D3B" ), HexColor( "#12131C" ), new Color( 0.16304554f, 2.03327346f, 1.62805736f, 1 ) } },
		{ "night2", new[]{ HexColor( "#172F4B" ), HexColor( "#0A1225" ), HexColor( "#040811" ), new Color( 0.16304554f, 2.03327346f, 1.62805736f, 1 ) } },
	};
	public Material canvasMat;
	public VisualEffect envVFX;
	public Light mainLight;

	public bool isday = true;
	bool _currentIsDay = false;
	Material _skyMat;
	void SetSkyMatColor( Color[] col, bool inDay ) {
		if( inDay ) {
			_skyMat.SetColor( "_DayBottomColor", col[0] );
			_skyMat.SetColor( "_DayMidColor", col[1] );
			_skyMat.SetColor( "_DayTopColor", col[2] );
			canvasMat.DOColor( col[3], "_TrailColor", 3f );
		} else {
			_skyMat.SetColor( "_NightBottomColor", col[0] );
			_skyMat.SetColor( "_NightMidColor", col[1] );
			_skyMat.SetColor( "_NightTopColor", col[2] );
			canvasMat.DOColor( col[3], "_TrailColor", 3f );
		}
	}

	void SetTime( bool isDay ) {
		if( isDay ) {
			mainLight.transform.DORotate( new Vector3( 150, 0, 0 ), 4f );
			envVFX.SendEvent( "DayTime" );
			envVFX.SetBool( "Daytime",true );
			SetSkyMatColor( Colors["day1"], true );
		} else {
			mainLight.transform.DORotate( new Vector3( -90, 0, 0 ), 4f );
			envVFX.SendEvent( "NightTime" );
			envVFX.SetBool( "Daytime",false );
			SetSkyMatColor( Colors["night2"], false );
		}
	}



	// Start is called before the first frame update
	void Start() {
		_skyMat = RenderSettings.skybox;
		SetSkyMatColor( Colors["day1"], true );
		SetSkyMatColor( Colors["night2"], false );
	}

	// Update is called once per frame
	void Update() {
		if(isday!=_currentIsDay){
			_currentIsDay = isday;
			SetTime( isday );
		}
	}
}