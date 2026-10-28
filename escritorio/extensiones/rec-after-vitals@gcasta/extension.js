import GLib from 'gi://GLib';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export default class RecAfterVitals extends Extension {
    enable() {
        this._box = Main.panel._rightBox;
        // Vitals se reinserta al cambiar de posición o recargarse: reordenar cada vez
        this._childAddedId = this._box.connect('child-added', () => this._queue());
        this._queue();
    }

    disable() {
        this._box.disconnect(this._childAddedId);
        if (this._idleId)
            GLib.source_remove(this._idleId);
        this._idleId = 0;
        this._box = null;
    }

    _queue() {
        if (this._idleId)
            return;
        this._idleId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            this._idleId = 0;
            this._reorder();
            return GLib.SOURCE_REMOVE;
        });
    }

    _reorder() {
        const rec = Main.panel.statusArea.screenRecording?.container;
        const vitals = Main.panel.statusArea.vitalsMenu?.container;
        if (!rec || !vitals || rec.get_parent() !== vitals.get_parent())
            return;
        vitals.get_parent().set_child_above_sibling(rec, vitals);
    }
}
