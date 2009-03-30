/*
 * Copyright (c) 2000, 2002 IBM Corp.  All rights reserved.
 * This file is made available under the terms of the Common Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/cpl-v10.html
 *
 * Port to the D programming language
 *   Frank Benoit <benoit@tionex.de>
 */
module org.eclipse.sleak.Sleak;

import org.eclipse.swt.SWT;
import org.eclipse.swt.graphics.DeviceData;
import org.eclipse.swt.graphics.Rectangle;
import org.eclipse.swt.graphics.GC;
import org.eclipse.swt.graphics.Point;
import org.eclipse.swt.graphics.Color;
import org.eclipse.swt.graphics.Font;
import org.eclipse.swt.graphics.FontData;
import org.eclipse.swt.graphics.Region;
import org.eclipse.swt.graphics.Cursor;
import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Shell;
import org.eclipse.swt.widgets.Canvas;
import org.eclipse.swt.widgets.Button;
import org.eclipse.swt.widgets.Label;
import org.eclipse.swt.widgets.List;
import org.eclipse.swt.widgets.Text;
import org.eclipse.swt.widgets.Event;
import org.eclipse.swt.widgets.Listener;
import org.eclipse.swt.widgets.MessageBox;

import java.lang.all;

public class Sleak {
    Display display;
    Shell shell;
    List list;
    Canvas canvas;
    Button start, stop, check;
    Text text;
    Label label;

    Object [] oldObjects;
    Exception [] oldErrors;
    Object [] objects;
    Exception [] errors;

public void open () {
    display = Display.getCurrent ();
    shell = new Shell (display);
    shell.setText ("S-Leak");
    list = new List (shell, SWT.BORDER | SWT.V_SCROLL);
    list.addListener (SWT.Selection, new class() Listener  {
        public void handleEvent (Event event) {
            refreshObject ();
        }
    });
    text = new Text (shell, SWT.BORDER | SWT.H_SCROLL | SWT.V_SCROLL);
    canvas = new Canvas (shell, SWT.BORDER);
    canvas.addListener (SWT.Paint, new class() Listener  {
        public void handleEvent (Event event) {
            paintCanvas (event);
        }
    });
    check = new Button (shell, SWT.CHECK);
    check.setText ("Stack");
    check.addListener (SWT.Selection, new class() Listener  {
        public void handleEvent (Event e) {
            toggleStackTrace ();
        }
    });
    start = new Button (shell, SWT.PUSH);
    start.setText ("Snap");
    start.addListener (SWT.Selection, new class() Listener  {
        public void handleEvent (Event event) {
            refreshAll ();
        }
    });
    stop = new Button (shell, SWT.PUSH);
    stop.setText ("Diff");
    stop.addListener (SWT.Selection, new class() Listener  {
        public void handleEvent (Event event) {
            refreshDifference ();
        }
    });
    label = new Label (shell, SWT.BORDER);
    label.setText ("0 object(s)");
    shell.addListener (SWT.Resize, new class() Listener  {
        public void handleEvent (Event e) {
            layout ();
        }
    });
    check.setSelection (false);
    text.setVisible (false);
    Point size = shell.getSize ();
    shell.setSize (size.x / 2, size.y / 2);
    shell.open ();
}

void refreshLabel () {
    int colors = 0, cursors = 0, fonts = 0, gcs = 0, images = 0, regions = 0;
    for (int i=0; i<objects.length; i++) {
        Object object = objects [i];
        if (cast(Color)object ) colors++;
        if (cast(Cursor)object ) cursors++;
        if (cast(Font)object ) fonts++;
        if (cast(GC)object ) gcs++;
        if (cast(Image)object ) images++;
        if (cast(Region)object ) regions++;
    }
    char[] string = "";
    if (colors !is 0) string ~= Format( "{} Color(s)\n", colors );
    if (cursors !is 0) string ~= Format( "{} Cursor(s)\n", cursors );
    if (fonts !is 0) string ~= Format( "{} Font(s)\n", fonts );
    if (gcs !is 0) string ~= Format( "{} GC(s)\n", gcs );
    if (images !is 0) string ~= Format( "{} Image(s)\n", images );
    /* Currently regions are not counted. */
//  if (regions !is 0) string += regions + " Region(s)\n";
    if (string.length !is 0) {
        string = string.substring (0, string.length - 1);
    }
    label.setText (string);
}

void refreshDifference () {
    DeviceData info = display.getDeviceData ();
    if (!info.tracking) {
        MessageBox dialog = new MessageBox (shell, SWT.ICON_WARNING | SWT.OK);
        dialog.setText (shell.getText ());
        dialog.setMessage ("Warning: Device is not tracking resource allocation");
        dialog.open ();
    }
    Object [] newObjects = info.objects;
    Exception [] newErrors = info.errors;
    Object [] diffObjects = new Object [newObjects.length];
    Exception [] diffErrors = new Exception [newErrors.length];
    int count = 0;
    for (int i=0; i<newObjects.length; i++) {
        int index = 0;
        while (index < oldObjects.length) {
            if (newObjects [i] is oldObjects [index]) break;
            index++;
        }
        if (index is oldObjects.length) {
            diffObjects [count] = newObjects [i];
            diffErrors [count] = newErrors [i];
            count++;
        }
    }
    objects = new Object [count];
    errors = new Exception [count];
    System.arraycopy (diffObjects, 0, objects, 0, count);
    System.arraycopy (diffErrors, 0, errors, 0, count);
    list.removeAll ();
    text.setText ("");
    canvas.redraw ();
    for (int i=0; i<objects.length; i++) {
        list.add (objectName (objects [i]));
    }
    refreshLabel ();
    layout ();
}

char[] objectName (Object object) {
    char[] string = object.toString ();
    int index = string.lastIndexOf ('.');
    if (index is -1) return string;
    return string.substring (index + 1, string.length);
}

void toggleStackTrace () {
    refreshObject ();
    layout ();
}

void paintCanvas (Event event) {
    canvas.setCursor (null);
    int index = list.getSelectionIndex ();
    if (index is -1) return;
    GC gc = event.gc;
    Object object = objects [index];
    if (cast(Color)object ) {
        if ((cast(Color)object).isDisposed ()) return;
        gc.setBackground (cast(Color) object);
        gc.fillRectangle (canvas.getClientArea());
        return;
    }
    if (cast(Cursor)object ) {
        if ((cast(Cursor)object).isDisposed ()) return;
        canvas.setCursor (cast(Cursor) object);
        return;
    }
    if (cast(Font)object ) {
        if ((cast(Font)object).isDisposed ()) return;
        gc.setFont (cast(Font) object);
        FontData [] array = gc.getFont ().getFontData ();
        char[] string = "";
        char[] lf = text.getLineDelimiter ();
        for (int i=0; i<array.length; i++) {
            FontData data = array [i];
            char[] style = "NORMAL";
            int bits = data.getStyle ();
            if (bits !is 0) {
                if ((bits & SWT.BOLD) !is 0) style = "BOLD ";
                if ((bits & SWT.ITALIC) !is 0) style ~= "ITALIC";
            }
            string ~= Format( "{} {} {}{}", data.getName (), data.getHeight (), style, lf );
        }
        gc.drawString (string, 0, 0);
        return;
    }
    //NOTHING TO DRAW FOR GC
//  if (object instanceof GC) {
//      return;
//  }
    if (cast(Image)object ) {
        if ((cast(Image)object).isDisposed ()) return;
        gc.drawImage (cast(Image) object, 0, 0);
        return;
    }
    if (cast(Region)object ) {
        if ((cast(Region)object).isDisposed ()) return;
        char[] string = (cast(Region)object).getBounds().toString();
        gc.drawString (string, 0, 0);
        return;
    }
}

void refreshObject () {
    int index = list.getSelectionIndex ();
    if (index is -1) return;
    if (check.getSelection ()) {
        char[] txt = "Stacktrace info (if missing you need stacktrace support for your program):\n";
        foreach( frame; errors[index].info ){
            txt ~= Format("{}:{}\n", frame.file, frame.line );
        }
        text.setText (txt);
        text.setVisible (true);
        canvas.setVisible (false);
    } else {
        canvas.setVisible (true);
        text.setVisible (false);
        canvas.redraw ();
    }
}

void refreshAll () {
    oldObjects = null;
    oldErrors = null;
    refreshDifference ();
    oldObjects = objects;
    oldErrors = errors;
}

void layout () {
    Rectangle rect = shell.getClientArea ();
    char[] [] strings = new char[] [](objects.length);
    int width = 0;
    char[] [] items = list.getItems ();
    GC gc = new GC (list);
    for (int i=0; i<objects.length; i++) {
        width = Math.max (width, gc.stringExtent (items [i]).x);
    }
    gc.dispose ();
    Point size1 = start.computeSize (SWT.DEFAULT, SWT.DEFAULT);
    Point size2 = stop.computeSize (SWT.DEFAULT, SWT.DEFAULT);
    Point size3 = check.computeSize (SWT.DEFAULT, SWT.DEFAULT);
    Point size4 = label.computeSize (SWT.DEFAULT, SWT.DEFAULT);
    width = Math.max (size1.x, Math.max (size2.x, Math.max (size3.x, width)));
    width = Math.max (64, Math.max (size4.x, list.computeSize (width, SWT.DEFAULT).x));
    start.setBounds (0, 0, width, size1.y);
    stop.setBounds (0, size1.y, width, size2.y);
    check.setBounds (0, size1.y + size2.y, width, size3.y);
    label.setBounds (0, rect.height - size4.y, width, size4.y);
    int height = size1.y + size2.y + size3.y;
    list.setBounds (0, height, width, rect.height - height - size4.y);
    text.setBounds (width, 0, rect.width - width, rect.height);
    canvas.setBounds (width, 0, rect.width - width, rect.height);
}

public static void main (char[] [] args) {
    Display display = new Display ();
    Sleak sleak = new Sleak ();
    sleak.open ();
    while (!sleak.shell.isDisposed ()) {
        if (!display.readAndDispatch ()) display.sleep ();
    }
    display.dispose ();
}

}
