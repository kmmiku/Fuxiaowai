package com.fuxiaowai.timetable;
import android.content.Intent;
import android.net.Uri;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
@CapacitorPlugin(name="UpdateLink")
public class UpdateLinkPlugin extends Plugin {
 @PluginMethod public void open(PluginCall call){
  try{
   Uri uri=Uri.parse(call.getString("url",""));
   if(!"https".equals(uri.getScheme())||uri.getHost()==null||uri.getUserInfo()!=null){call.reject("Invalid update address");return;}
   getActivity().startActivity(new Intent(Intent.ACTION_VIEW,uri));
   call.resolve();
  }catch(Exception e){call.reject("Unable to open update address");}
 }
}