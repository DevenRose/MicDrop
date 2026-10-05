using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using System.Threading;
using System.Diagnostics;
using Forms = System.Windows.Forms;
using Drawing = System.Drawing;

namespace MicDropEqualizer {
 [DataContract] public class Profile {
  [DataMember] public string Name;
  [DataMember] public string Layout="31";
  [DataMember] public double[] Frequencies;
  [DataMember] public double[] Gains;
  [DataMember] public double Preamp=-3;
  [DataMember] public string BaseFilters="";
 }
 [DataContract] public class Settings {
  [DataMember] public List<Profile> Profiles=new List<Profile>();
  [DataMember] public double FontPoints=12;
  [DataMember] public double Width=1200;
  [DataMember] public double Height=800;
  [DataMember] public bool Maximized=false;
  [DataMember] public int RenderRate=48000,CaptureRate=16000;
 }
 public static class Eq {
  public const string Render="{b56632b2-8e96-4c11-a623-8e233b195adb}";
  public const string Capture="{7c806a74-2036-47d5-b3fe-1a0aa19bb13e}";
  public const string LegacyCall="{50c13f97-8076-409c-8c5d-b95c6a3deedd}";
  public static readonly double[] Third={20,25,31.5,40,50,63,80,100,125,160,200,250,315,400,500,630,800,1000,1250,1600,2000,2500,3150,4000,5000,6300,8000,10000,12500,16000,20000};
  public static readonly double[] Half={25,40,63,100,160,250,400,630,1000,1600,2500,4000,6300,10000,16000};
  public static readonly double[] Octave={31.5,63,125,250,500,1000,2000,4000,8000,16000};
  public static string Number(double n) {return n.ToString("0.###",CultureInfo.InvariantCulture);}
  public static double[] Bands(string layout,int rate) {
   double[] all=layout=="10" ? Octave : layout=="15" ? Half : Third;
   return all.Where(f=>f<rate/2.0 && f<=20000).ToArray();
  }
  public static double Interpolate(Profile p,double frequency) {
   if(p.Frequencies==null || p.Frequencies.Length==0)return 0;
   if(frequency<=p.Frequencies[0])return p.Gains[0];
   for(int i=1;i<p.Frequencies.Length;i++)if(frequency<=p.Frequencies[i]) {
    double t=Math.Log(frequency/p.Frequencies[i-1])/Math.Log(p.Frequencies[i]/p.Frequencies[i-1]);
    return p.Gains[i-1]+t*(p.Gains[i]-p.Gains[i-1]);
   }
   return p.Gains[p.Gains.Length-1];
  }
  public static void ChangeBands(Profile p,string layout,int rate) {
   double[] next=Bands(layout,rate); double[] gains=next.Select(f=>Interpolate(p,f)).ToArray();
   p.Layout=layout;p.Frequencies=next;p.Gains=gains;
  }
  public static string Section(string device,Profile p,int rate) {
   StringBuilder text=new StringBuilder("Device: "+device+"\r\nChannel: all\r\n");
   // Preserve a minimum of the existing base headroom, and offset added boosts.
   double positive=p.Gains.Length==0?0:Math.Max(0,p.Gains.Max());
   text.Append("Preamp: "+Number(Math.Min(0,p.Preamp)-positive)+" dB\r\n");
   if(!String.IsNullOrWhiteSpace(p.BaseFilters))text.Append(p.BaseFilters.Trim()+"\r\n");
   List<string> points=new List<string>();
   for(int i=0;i<p.Frequencies.Length;i++)if(p.Frequencies[i]>0 && p.Frequencies[i]<rate/2.0)
    points.Add(Number(p.Frequencies[i])+" "+Number(p.Gains[i]));
   if(points.Count>0)text.Append("GraphicEQ: "+String.Join("; ",points)+"\r\n");
   return text.ToString();
  }
  public static string Configuration(Settings s,bool call,int renderRate,int captureRate) {
   return "# MicDrop Equalizer — standard bands; full-range playback outside calls\r\n"+
    Section(Capture,s.Profiles[2],captureRate)+"\r\n"+
    Section(LegacyCall,s.Profiles[1],captureRate)+"\r\n"+
    Section(Render,s.Profiles[call?1:0],call?Math.Min(renderRate,captureRate):renderRate);
  }
  public static void AtomicWrite(string path,string contents) {
   string temp=path+".new";File.WriteAllText(temp,contents,new UTF8Encoding(false));
   if(File.Exists(path))File.Replace(temp,path,null);else File.Move(temp,path);
  }
  public static Settings Load(string root,int renderRate,int captureRate) {
   string path=Path.Combine(root,"micdrop-equalizer.json");
   if(File.Exists(path))using(FileStream f=File.OpenRead(path)) {
    Settings loaded=(Settings)new DataContractJsonSerializer(typeof(Settings)).ReadObject(f);
    if(loaded.Profiles==null || loaded.Profiles.Count!=3)throw new InvalidDataException("Saved profiles are incomplete.");
    foreach(Profile p in loaded.Profiles)if(p.Frequencies==null || p.Gains==null || p.Frequencies.Length!=p.Gains.Length || p.Frequencies.Any(n=>n<=0 || Double.IsNaN(n)) || p.Gains.Any(n=>Double.IsNaN(n) || Double.IsInfinity(n) || Math.Abs(n)>60))throw new InvalidDataException("Saved EQ values are invalid.");
    return loaded;
   }
   Settings s=new Settings {RenderRate=renderRate,CaptureRate=captureRate};
   s.Profiles.Add(new Profile {Name="Normal playback",Frequencies=Bands("31",renderRate)});
   s.Profiles.Add(new Profile {Name="Call playback",Frequencies=Bands("31",Math.Min(renderRate,captureRate))});
   s.Profiles.Add(new Profile {Name="My microphone",Frequencies=Bands("31",captureRate)});
   foreach(Profile p in s.Profiles)p.Gains=new double[p.Frequencies.Length];
   // Retain the exact existing voice shaping rather than silently losing it.
   string file=Path.Combine(root,"TOZO Voice.peace");
   if(File.Exists(file)) {
    Dictionary<string,string> ini=ReadIni(file); StringBuilder filters=new StringBuilder();
    for(int i=1;i<=31;i++) {
     double hz=Read(ini,"Frequencies/Frequency"+i,0);if(hz<=0 || hz>=captureRate/2.0)continue;
     double gain=Read(ini,"Gains/Gain"+i,0),q=Read(ini,"Qualities/Quality"+i,1.41);
     int type=(int)Read(ini,"Filters/Filter"+i,0);
     if(type!=0 && type!=2)throw new InvalidDataException("The voice preset uses an unsupported base filter; preserve it before migration.");
     filters.Append("Filter: ON "+(type==2?"HPQ":"PK")+" Fc "+Number(hz)+" Hz "+(type==2?"":"Gain "+Number(gain)+" dB ")+"Q "+Number(q)+"\r\n");
    }
    s.Profiles[2].BaseFilters=filters.ToString();s.Profiles[2].Preamp=Read(ini,"General/PreAmp",-3);
   }
   return s;
  }
  public static Dictionary<string,string> ReadIni(string file) {
   Dictionary<string,string> data=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);string section="";
   foreach(string raw in File.ReadAllLines(file)) {
    string line=raw.Trim();if(line.StartsWith("[")){section=line.Trim('[',']');continue;}
    int equal=line.IndexOf('=');if(equal>0)data[section+"/"+line.Substring(0,equal)]=line.Substring(equal+1);
   }return data;
  }
  static double Read(Dictionary<string,string> data,string key,double fallback) {
   string value;double number;return data.TryGetValue(key,out value)&&Double.TryParse(value,NumberStyles.Float,CultureInfo.InvariantCulture,out number)?number:fallback;
  }
  public static void Save(string root,Settings settings) {
   using(MemoryStream f=new MemoryStream()) {
    new DataContractJsonSerializer(typeof(Settings)).WriteObject(f,settings);
    AtomicWrite(Path.Combine(root,"micdrop-equalizer.json"),Encoding.UTF8.GetString(f.ToArray()));
   }
  }
 }

 // Windows' Core Audio API: read mix formats and only the TOZO capture session state.
 [ComImport,Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMEnumerator {}
 [ComImport,Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface IMMEnumerator {
  [PreserveSig]int EnumAudioEndpoints(int flow,uint mask,out IntPtr devices);
  [PreserveSig]int GetDefaultAudioEndpoint(int flow,int role,out IMMDevice device);
  [PreserveSig]int GetDevice([MarshalAs(UnmanagedType.LPWStr)]string id,out IMMDevice device);
 }
 [ComImport,Guid("D666063F-1587-4E43-81F1-B948E807363F"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface IMMDevice {
  [PreserveSig]int Activate(ref Guid iid,uint context,IntPtr parameters,[MarshalAs(UnmanagedType.IUnknown)]out object instance);
 }
 [ComImport,Guid("1CB9AD4C-DBFA-4C32-B178-C2F568A703B2"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface IAudioClient {
  [PreserveSig]int Initialize(int mode,uint flags,long duration,long periodicity,IntPtr format,ref Guid session);
  [PreserveSig]int GetBufferSize(out uint frames);
  [PreserveSig]int GetStreamLatency(out long latency);
  [PreserveSig]int GetCurrentPadding(out uint frames);
  [PreserveSig]int IsFormatSupported(int mode,IntPtr format,out IntPtr closest);
  [PreserveSig]int GetMixFormat(out IntPtr format);
 }
 [ComImport,Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface ISessionManager {
  [PreserveSig]int GetAudioSessionControl(ref Guid session,uint flags,out IntPtr control);
  [PreserveSig]int GetSimpleAudioVolume(ref Guid session,uint flags,out IntPtr volume);
  [PreserveSig]int GetSessionEnumerator(out ISessions sessions);
 }
 [ComImport,Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface ISessions {
  [PreserveSig]int GetCount(out int count);
  [PreserveSig]int GetSession(int index,out ISession session);
 }
 [ComImport,Guid("F4B1A599-7266-4319-A8CA-E70ACB11E8CD"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface ISession {
  [PreserveSig]int GetState(out int state);
 }
 public class AudioSnapshot {
  public int RenderRate=48000,CaptureRate=16000;
  public bool Call,Verified;
  public string Error="";
 }
 public static class Audio {
  static void Check(int result){Marshal.ThrowExceptionForHR(result);}
  static void Release(object o){if(o!=null && Marshal.IsComObject(o))Marshal.ReleaseComObject(o);}
  static IMMDevice Device(IMMEnumerator e,string guid,bool capture) {
   IMMDevice d;Check(e.GetDevice((capture?"{0.0.1.00000000}.":"{0.0.0.00000000}.")+guid,out d));return d;
  }
  static int Rate(IMMDevice d) {
   object client=null;IntPtr format=IntPtr.Zero;
   try {Guid id=new Guid("1CB9AD4C-DBFA-4C32-B178-C2F568A703B2");Check(d.Activate(ref id,23,IntPtr.Zero,out client));
    Check(((IAudioClient)client).GetMixFormat(out format));return Marshal.ReadInt32(format,4);
   }finally{if(format!=IntPtr.Zero)Marshal.FreeCoTaskMem(format);Release(client);}
  }
  public static AudioSnapshot Read() {
   AudioSnapshot answer=new AudioSnapshot();object enumerator=null,manager=null;IMMDevice render=null,capture=null;ISessions sessions=null;
   try {
    enumerator=new MMEnumerator();IMMEnumerator e=(IMMEnumerator)enumerator;
    render=Device(e,Eq.Render,false);capture=Device(e,Eq.Capture,true);
    answer.RenderRate=Rate(render);answer.CaptureRate=Rate(capture);
    Guid id=new Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F");Check(capture.Activate(ref id,23,IntPtr.Zero,out manager));
    Check(((ISessionManager)manager).GetSessionEnumerator(out sessions));int count;Check(sessions.GetCount(out count));
    for(int i=0;i<count;i++){ISession session=null;try {Check(sessions.GetSession(i,out session));int state;Check(session.GetState(out state));if(state==1)answer.Call=true;}finally{Release(session);}}
    answer.Verified=true;
   }catch(Exception ex){answer.Error=ex.Message;}
   finally{Release(sessions);Release(manager);Release(capture);Release(render);Release(enumerator);}
   return answer;
  }
 }

 public class EqualizerWindow : Window {
  readonly string root;readonly bool testing;readonly Settings saved;
  AudioSnapshot audio;Profile current;int target;bool building,exit;
  readonly StackPanel content=new StackPanel();readonly WrapPanel bands=new WrapPanel();
  readonly ComboBox targetPicker=new ComboBox(),layoutPicker=new ComboBox(),fontPicker=new ComboBox();
  readonly TextBlock status=new TextBlock(),range=new TextBlock(),notice=new TextBlock();
  readonly ScrollViewer scroll=new ScrollViewer();readonly List<Slider> sliders=new List<Slider>();
  readonly DispatcherTimer saveTimer=new DispatcherTimer(),audioTimer=new DispatcherTimer();
  Forms.NotifyIcon tray;Drawing.Icon appIcon;
  static readonly Brush BackgroundColor=new SolidColorBrush(Color.FromRgb(23,26,32));
  static readonly Brush PanelColor=new SolidColorBrush(Color.FromRgb(34,39,48));
  static readonly Brush TextColor=new SolidColorBrush(Color.FromRgb(239,243,249));
  public EqualizerWindow(string directory,bool test) {
   root=directory;testing=test;audio=Audio.Read();
   saved=Eq.Load(root,audio.RenderRate,audio.CaptureRate);
   if(!audio.Verified){audio.RenderRate=saved.RenderRate;audio.CaptureRate=saved.CaptureRate;}
   Title="MicDrop Equalizer · TOZO HT3";Width=Math.Max(360,saved.Width);Height=Math.Max(320,saved.Height);
   if(!File.Exists(Path.Combine(root,"micdrop-equalizer.json"))){Width=Math.Min(Width,SystemParameters.WorkArea.Width);Height=Math.Min(Height,SystemParameters.WorkArea.Height);}
   WindowStartupLocation=WindowStartupLocation.CenterScreen;MinWidth=320;MinHeight=240;ResizeMode=ResizeMode.CanResize;ShowInTaskbar=true;
   Background=BackgroundColor;Foreground=TextColor;FontFamily=new FontFamily("Segoe UI");FontSize=saved.FontPoints*96/72;
   ResourceDictionary resources=Resources;
   Style buttonStyle=new Style(typeof(Button));buttonStyle.Setters.Add(new Setter(Control.PaddingProperty,new Thickness(12,7,12,7)));
   buttonStyle.Setters.Add(new Setter(Control.BackgroundProperty,PanelColor));buttonStyle.Setters.Add(new Setter(Control.ForegroundProperty,TextColor));resources.Add(typeof(Button),buttonStyle);
   content.Margin=new Thickness(18);scroll.Content=content;scroll.VerticalScrollBarVisibility=ScrollBarVisibility.Auto;scroll.HorizontalContentAlignment=HorizontalAlignment.Stretch;
   scroll.HorizontalScrollBarVisibility=ScrollBarVisibility.Disabled;Content=scroll;
   TextBlock title=new TextBlock {Text="TOZO HT3 Equalizer",FontSize=FontSize*1.45,FontWeight=FontWeights.SemiBold,Margin=new Thickness(0,0,0,12),TextWrapping=TextWrapping.Wrap};content.Children.Add(title);
   WrapPanel toolbar=new WrapPanel {Margin=new Thickness(0,0,0,10)};content.Children.Add(toolbar);
   AddPicker(toolbar,"Editing",targetPicker,new string[]{"Normal playback","Call playback","My microphone"},0);
   AddPicker(toolbar,"Bands",layoutPicker,new string[]{"10 · octave","15 · two-thirds octave","31 · third octave"},2);
   AddPicker(toolbar,"Text size",fontPicker,new string[]{"9 pt","10 pt","12 pt","14 pt","16 pt","18 pt","24 pt"},Array.IndexOf(new double[]{9,10,12,14,16,18,24},saved.FontPoints));
   Button flat=new Button {Content="Flat bands",Margin=new Thickness(0,20,8,0)};toolbar.Children.Add(flat);
   Button hide=new Button {Content="To tray",Margin=new Thickness(0,20,8,0)};toolbar.Children.Add(hide);
   status.TextWrapping=TextWrapping.Wrap;status.Margin=new Thickness(0,5,0,8);content.Children.Add(status);
   range.TextWrapping=TextWrapping.Wrap;range.Foreground=new SolidColorBrush(Color.FromRgb(116,208,226));range.Margin=new Thickness(0,0,0,12);content.Children.Add(range);
   content.Children.Add(bands);notice.TextWrapping=TextWrapping.Wrap;notice.Margin=new Thickness(0,12,0,6);content.Children.Add(notice);
   TextBlock help=new TextBlock {Text="Changes save automatically. Drag an edge to resize, or use the title-bar maximize button. Bands wrap into rows; scroll when the window is small. Closing the window keeps the tray icon available.",TextWrapping=TextWrapping.Wrap,Margin=new Thickness(0,12,0,0),Opacity=0.75};content.Children.Add(help);
   targetPicker.SelectionChanged+=delegate{if(!building){target=targetPicker.SelectedIndex;ShowProfile();}};
   layoutPicker.SelectionChanged+=delegate{if(!building){Eq.ChangeBands(current,new string[]{"10","15","31"}[layoutPicker.SelectedIndex],TargetRate());ShowProfile();Schedule();}};
   fontPicker.SelectionChanged+=delegate{if(!building){saved.FontPoints=new double[]{9,10,12,14,16,18,24}[fontPicker.SelectedIndex];FontSize=saved.FontPoints*96/72;title.FontSize=FontSize*1.45;ShowProfile();Schedule();}};
   flat.Click+=delegate{Array.Clear(current.Gains,0,current.Gains.Length);ShowProfile();Schedule();};hide.Click+=delegate{Hide();};
   SizeChanged+=delegate{LayoutBands();};scroll.ScrollChanged+=delegate(object sender,ScrollChangedEventArgs change){if(change.ViewportWidthChange!=0 || change.ViewportHeightChange!=0)LayoutBands();};
   saveTimer.Interval=TimeSpan.FromMilliseconds(180);saveTimer.Tick+=delegate{saveTimer.Stop();SaveAndApply();};
   audioTimer.Interval=TimeSpan.FromSeconds(1);audioTimer.Tick+=delegate{PollAudio();};
   Closing+=delegate(object sender,System.ComponentModel.CancelEventArgs args){if(!exit){args.Cancel=true;SaveGeometry();Hide();}};
   Closed+=delegate{audioTimer.Stop();saveTimer.Stop();if(tray!=null){tray.Visible=false;tray.Dispose();}if(appIcon!=null)appIcon.Dispose();};
   MakeTray();ShowProfile();
   SourceInitialized+=delegate{((HwndSource)PresentationSource.FromVisual(this)).AddHook(delegate(IntPtr hwnd,int message,IntPtr wparam,IntPtr lparam,ref bool handled){if(message==0x8010){RestoreWindow();handled=true;}else if(message==0x8011){ExitApp();handled=true;}return IntPtr.Zero;});};
   Loaded+=delegate{if(saved.Maximized)WindowState=WindowState.Maximized;LayoutBands();if(testing)StartTests();else{SaveAndApply();audioTimer.Start();}};
  }
  void AddPicker(Panel toolbar,string label,ComboBox picker,string[] values,int selected) {
   StackPanel field=new StackPanel {Margin=new Thickness(0,0,12,6)};
   field.Children.Add(new TextBlock {Text=label,Margin=new Thickness(0,0,0,4)});
   picker.ItemsSource=values;picker.SelectedIndex=Math.Max(0,selected);picker.Padding=new Thickness(7,4,7,4);picker.MinWidth=100;
   field.Children.Add(picker);toolbar.Children.Add(field);
  }
  int TargetRate(){return target==0?audio.RenderRate:target==1?Math.Min(audio.RenderRate,audio.CaptureRate):audio.CaptureRate;}
  void ShowProfile() {
   building=true;current=saved.Profiles[target];bands.Children.Clear();sliders.Clear();
   layoutPicker.SelectedIndex=Array.IndexOf(new string[]{"10","15","31"},current.Layout);
   double[] valid=Eq.Bands(current.Layout,TargetRate());
   if(!current.Frequencies.SequenceEqual(valid))Eq.ChangeBands(current,current.Layout,TargetRate());
   for(int i=0;i<current.Frequencies.Length;i++) {
    int index=i;Profile edited=current;StackPanel column=new StackPanel();
    TextBlock frequency=new TextBlock {Text=current.Frequencies[i]>=1000?Eq.Number(current.Frequencies[i]/1000)+" kHz":Eq.Number(current.Frequencies[i])+" Hz",TextAlignment=TextAlignment.Center,FontWeight=FontWeights.SemiBold};column.Children.Add(frequency);
    TextBlock gain=new TextBlock {Text=Eq.Number(current.Gains[i])+" dB",TextAlignment=TextAlignment.Center,Margin=new Thickness(0,6,0,4)};column.Children.Add(gain);
    TextBox value=null;
    Slider slider=new Slider {Minimum=-12,Maximum=12,Value=current.Gains[i],Orientation=Orientation.Vertical,TickFrequency=3,TickPlacement=TickPlacement.Both,IsSnapToTickEnabled=false,SmallChange=0.1,LargeChange=1,Margin=new Thickness(4,2,4,2)};
    slider.ValueChanged+=delegate{if(!building && index<edited.Gains.Length){edited.Gains[index]=Math.Round(slider.Value,1);gain.Text=Eq.Number(edited.Gains[index])+" dB";if(value!=null)value.Text=Eq.Number(edited.Gains[index]);Schedule();}};
    column.Children.Add(slider);sliders.Add(slider);
    value=new TextBox {Text=Eq.Number(current.Gains[i]),HorizontalContentAlignment=HorizontalAlignment.Center,Margin=new Thickness(4,6,4,0),Padding=new Thickness(3),ToolTip="Gain in decibels, from -12 to +12"};column.Children.Add(value);
    Action commit=delegate{if(index>=edited.Gains.Length)return;double entered;if(Double.TryParse(value.Text,NumberStyles.Float,CultureInfo.InvariantCulture,out entered)&&entered>=-12&&entered<=12){slider.Value=entered;}value.Text=Eq.Number(edited.Gains[index]);};
    value.LostKeyboardFocus+=delegate{commit();};value.KeyDown+=delegate(object sender,System.Windows.Input.KeyEventArgs args){if(args.Key==System.Windows.Input.Key.Enter)commit();};
    Border card=new Border {Child=column,Background=PanelColor,CornerRadius=new CornerRadius(7),Padding=new Thickness(8),Margin=new Thickness(4)};bands.Children.Add(card);
   }
   range.Text=current.Name+" · "+current.Frequencies.Length+" active bands · "+Eq.Number(current.Frequencies.First())+" Hz–"+Eq.Number(current.Frequencies.Last()/1000)+" kHz · "+TargetRate()+" Hz Windows format";
   UpdateStatus();LayoutBands();building=false;
  }
  void LayoutBands() {
   double width=Math.Max(200,scroll.ViewportWidth>0?scroll.ViewportWidth-36:ActualWidth-62),minimum=Math.Max(92,FontSize*6.2);
   int columns=Math.Max(1,(int)Math.Floor(width/minimum));double cardWidth=Math.Max(minimum-8,width/columns-8);
   int rows=Math.Max(1,(int)Math.Ceiling(bands.Children.Count/(double)columns));
   double other=36;
   foreach(FrameworkElement element in content.Children)if(element!=bands)other+=element.ActualHeight+element.Margin.Top+element.Margin.Bottom;
   double overhead=FontSize*3.6+44;
   double sliderHeight=Math.Max(72,Math.Min(360,((scroll.ViewportHeight>0?scroll.ViewportHeight:ActualHeight-40)-other)/rows-overhead));
   foreach(Border card in bands.Children){card.Width=cardWidth;}
   foreach(Slider slider in sliders)slider.Height=sliderHeight;
  }
  void UpdateStatus() {
   status.Text=!audio.Verified?"TOZO status unavailable; keeping the last verified mode. "+audio.Error:
    (audio.Call?"Active output: call playback · TOZO microphone is in use":"Active output: normal playback · full range")+". Microphone EQ stays enabled.";
  }
  void PollAudio() {
   AudioSnapshot next=Audio.Read();if(!next.Verified){audio.Verified=false;audio.Error=next.Error;UpdateStatus();return;}
   bool changed=next.Call!=audio.Call || next.RenderRate!=audio.RenderRate || next.CaptureRate!=audio.CaptureRate;
   audio=next;UpdateStatus();if(changed){ShowProfile();SaveAndApply();}
  }
  void Schedule(){notice.Text="Saving…";saveTimer.Stop();saveTimer.Start();}
  void SaveGeometry() {
   Rect r=RestoreBounds;if(WindowState==WindowState.Normal){saved.Width=Width;saved.Height=Height;}else if(!r.IsEmpty){saved.Width=r.Width;saved.Height=r.Height;}
   saved.Maximized=WindowState==WindowState.Maximized;Eq.Save(root,saved);
  }
  void SaveAndApply() {
   try {
    if(audio.Verified){saved.RenderRate=audio.RenderRate;saved.CaptureRate=audio.CaptureRate;}
    SaveGeometry();if(!audio.Verified){notice.Text="TOZO is unavailable; saved changes will apply after reconnecting.";return;}
    Eq.AtomicWrite(Path.Combine(root,"micdrop-eq.txt"),Eq.Configuration(saved,audio.Call,audio.RenderRate,audio.CaptureRate));
    notice.Text="Saved · automatic headroom protects against boosts clipping"+(target==2&&!String.IsNullOrWhiteSpace(current.BaseFilters)?" · original voice filters retained":"");
   }catch(Exception ex){notice.Text="Could not save: "+ex.Message;}
  }
  void MakeTray() {
   Drawing.Bitmap bitmap=new Drawing.Bitmap(32,32);using(Drawing.Graphics graphics=Drawing.Graphics.FromImage(bitmap)) {
    graphics.Clear(Drawing.Color.FromArgb(23,26,32));using(Drawing.Pen pen=new Drawing.Pen(Drawing.Color.FromArgb(116,208,226),3)) {
     graphics.DrawArc(pen,6,7,20,18,0,180);graphics.DrawLine(pen,16,24,16,29);graphics.DrawLine(pen,10,29,22,29);
     graphics.DrawRectangle(pen,12,4,8,16);
    }
   }
   IntPtr handle=bitmap.GetHicon();try{using(Drawing.Icon original=Drawing.Icon.FromHandle(handle)){appIcon=(Drawing.Icon)original.Clone();}}finally{DestroyIcon(handle);bitmap.Dispose();}
   Icon=Imaging.CreateBitmapSourceFromHIcon(appIcon.Handle,Int32Rect.Empty,BitmapSizeOptions.FromEmptyOptions());
   tray=new Forms.NotifyIcon {Icon=appIcon,Text="MicDrop Equalizer · TOZO HT3",Visible=true};
   Forms.ContextMenuStrip menu=new Forms.ContextMenuStrip();
   menu.Items.Add("Show equalizer",null,delegate{RestoreWindow();});menu.Items.Add("Hide window",null,delegate{Hide();});
   menu.Items.Add("Exit equalizer",null,delegate{ExitApp();});tray.ContextMenuStrip=menu;
   tray.DoubleClick+=delegate{RestoreWindow();};
  }
  [DllImport("user32.dll")]static extern bool DestroyIcon(IntPtr handle);
  void RestoreWindow(){Show();if(WindowState==WindowState.Minimized)WindowState=WindowState.Normal;Activate();}
  void ExitApp(){if(!testing){audio.Call=false;SaveAndApply();}exit=true;Close();Application.Current.Shutdown();}
  void StartTests() {
   List<string> results=new List<string>();int step=0;bool passed=true;
   DispatcherTimer timer=new DispatcherTimer {Interval=TimeSpan.FromMilliseconds(400)};
   timer.Tick+=delegate {
    try {
     if(step==0){Width=360;Height=550;FontSize=16;ShowProfile();}
     else if(step==1){ValidateLayout("narrow",results,ref passed);Render("narrow.png");Width=1250;Height=820;}
     else if(step==2){ValidateLayout("wide",results,ref passed);Render("wide.png");fontPicker.SelectedIndex=6;Width=650;}
     else if(step==3){ValidateLayout("large-text",results,ref passed);Render("large-text.png");fontPicker.SelectedIndex=2;WindowState=WindowState.Maximized;}
     else if(step==4){ValidateLayout("maximized",results,ref passed);Render("maximized.png");passed&=WindowState==WindowState.Maximized && ShowInTaskbar && tray.Visible;WindowState=WindowState.Normal;}
     else if(step==5){passed&=WindowState==WindowState.Normal && audio.Verified;TestEngine(results,ref passed);SaveAndApply();results.Add("verifiedRenderRate="+audio.RenderRate);results.Add("verifiedCaptureRate="+audio.CaptureRate);results.Add("audioVerified="+audio.Verified);results.Add("audioError="+audio.Error);results.Add("passed="+passed);File.WriteAllLines(Path.Combine(root,"self-test.txt"),results);timer.Stop();ExitApp();return;}
     step++;
    }catch(Exception ex){timer.Stop();File.WriteAllText(Path.Combine(root,"self-test-error.txt"),ex.ToString());ExitApp();}
   };timer.Start();
  }
  void ValidateLayout(string name,List<string> results,ref bool passed) {
   UpdateLayout();int last=bands.Children.Count-1;Point end=((Border)bands.Children[last]).TranslatePoint(new Point(),bands);
   int clipped=0;foreach(Border card in bands.Children){StackPanel panel=(StackPanel)card.Child;foreach(UIElement child in panel.Children){TextBlock label=child as TextBlock;if(label!=null && label.ActualWidth+0.5<label.DesiredSize.Width-label.Margin.Left-label.Margin.Right)clipped++;}}
   results.Add(name+": width="+ActualWidth+" height="+ActualHeight+" finalBandY="+end.Y+" clippedText="+clipped);
   passed&=clipped==0 && bands.Children.Count==31;
  }
  void TestEngine(List<string> results,ref bool passed) {
   string normal=Eq.Configuration(saved,false,48000,16000),call=Eq.Configuration(saved,true,48000,16000);
   string[] normalDevice=normal.Split(new string[]{"Device: "+Eq.Render},StringSplitOptions.None);
   string[] callDevice=call.Split(new string[]{"Device: "+Eq.Render},StringSplitOptions.None);
   bool ranges=normalDevice[1].Contains("20000 0")&&!callDevice[1].Contains("8000 ")&&callDevice[1].Contains("6300 0");passed&=ranges;
   Profile media=saved.Profiles[0];media.Gains[0]=6;string boost=Eq.Section(Eq.Render,media,48000);passed&=boost.Contains("Preamp: -9 dB");media.Gains[0]=0;
   sliders[3].Value=3;TextBox edited=(TextBox)((StackPanel)((Border)bands.Children[3]).Child).Children[3];passed&=edited.Text=="3" && media.Gains[3]==3;sliders[3].Value=0;
   Eq.ChangeBands(media,"10",48000);passed&=media.Frequencies.SequenceEqual(Eq.Octave);Eq.ChangeBands(media,"31",48000);
   results.Add("standard31NormalBands="+saved.Profiles[0].Frequencies.Length);results.Add("actual16kCallBands="+saved.Profiles[1].Frequencies.Length);results.Add("separateModeRanges="+ranges);
   File.WriteAllText(Path.Combine(root,"normal-test.txt"),normal);File.WriteAllText(Path.Combine(root,"call-test.txt"),call);
  }
  void Render(string name) {
   UpdateLayout();RenderTargetBitmap image=new RenderTargetBitmap(Math.Max(1,(int)ActualWidth),Math.Max(1,(int)ActualHeight),96,96,PixelFormats.Pbgra32);image.Render(this);
   PngBitmapEncoder encoder=new PngBitmapEncoder();encoder.Frames.Add(BitmapFrame.Create(image));using(FileStream file=File.Create(Path.Combine(root,name)))encoder.Save(file);
  }
 }
 static class Program {
  [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern IntPtr FindWindow(string className,string title);
  [DllImport("user32.dll")]static extern bool PostMessage(IntPtr window,int message,IntPtr wparam,IntPtr lparam);
  [STAThread]static void Main(string[] args) {
   bool testing=args.Contains("--self-test");string root=AppDomain.CurrentDomain.BaseDirectory;
   try {
    if(args.Contains("--probe-audio")) {
     List<string> states=new List<string>();for(int i=0;i<40;i++){AudioSnapshot state=Audio.Read();states.Add("verified="+state.Verified+" call="+state.Call+" render="+state.RenderRate+" capture="+state.CaptureRate+" error="+state.Error);System.Threading.Thread.Sleep(200);}File.WriteAllLines(Path.Combine(root,"audio-mode-probe.txt"),states);return;
    }
    if(args.Contains("--initialize")) {
     AudioSnapshot actual=Audio.Read();if(!actual.Verified)throw new InvalidOperationException("Cannot initialize without verified TOZO formats: "+actual.Error);
     Settings first=Eq.Load(root,actual.RenderRate,actual.CaptureRate);Eq.Save(root,first);Eq.AtomicWrite(Path.Combine(root,"micdrop-eq.txt"),Eq.Configuration(first,actual.Call,actual.RenderRate,actual.CaptureRate));File.WriteAllText(Path.Combine(root,"micdrop-initialized.txt"),"verifiedRenderRate="+actual.RenderRate+"\nverifiedCaptureRate="+actual.CaptureRate+"\ncall="+actual.Call+"\nsuccess=True");return;
    }
    if(testing && !root.StartsWith("X:\\Downloads\\MicDrop-EQ-2026-10-05\\",StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("Self-tests must run against throwaway staging files.");
    bool firstInstance;using(Mutex mutex=new Mutex(true,"Local\\MicDropEqualizer-TOZO-HT3",out firstInstance)) {
    if(!testing && !firstInstance){IntPtr existing=FindWindow(null,"MicDrop Equalizer · TOZO HT3");if(existing!=IntPtr.Zero)PostMessage(existing,0x8010,IntPtr.Zero,IntPtr.Zero);return;}
    Application app=new Application();app.ShutdownMode=ShutdownMode.OnExplicitShutdown;
    app.DispatcherUnhandledException+=delegate(object sender,DispatcherUnhandledExceptionEventArgs e){File.WriteAllText(Path.Combine(root,"micdrop-equalizer-error.txt"),e.Exception.ToString());e.Handled=true;app.Shutdown(1);};
    EqualizerWindow window=new EqualizerWindow(root,testing);app.Run(window);
    }
   }catch(Exception ex){File.WriteAllText(Path.Combine(root,"micdrop-equalizer-error.txt"),ex.ToString());}
  }
 }
}
