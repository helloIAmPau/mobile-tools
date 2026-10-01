package io.helloiampau.mobiletools.smoke;

import android.app.Activity;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.TextView;

public class MainActivity extends Activity {
    @Override
    public void onCreate(Bundle state) {
        super.onCreate(state);
        TextView title = new TextView(this);
        title.setText("Mobile tools ready");
        title.setGravity(Gravity.CENTER);
        setContentView(title);
    }
}
