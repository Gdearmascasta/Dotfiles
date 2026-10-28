

import Gtk from 'gi://Gtk';
import Gdk from 'gi://Gdk';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Adw from 'gi://Adw';
import { ExtensionPreferences, gettext as _ } from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';

const SETTINGS_APPLY_DELAY_TIME = 500;

export default class AppGridTunerPrefs extends ExtensionPreferences {
  fillPreferencesWindow(window) {
    const settings = this.getSettings();
    const refreshHandlers = {};
    let isRefreshing = false;

    let reloadSourceId = null;
    const scheduleReload = () => {
      if (reloadSourceId)
        GLib.Source.remove(reloadSourceId);
      reloadSourceId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, SETTINGS_APPLY_DELAY_TIME, () => {
        settings.set_boolean('reload-signal', !settings.get_boolean('reload-signal'));
        reloadSourceId = null;
        return GLib.SOURCE_REMOVE;
      });
    };

    const addSpinIntRow = (group, key, min, max, step) => {
      const row = new Adw.ActionRow({
        title: settings.settings_schema.get_key(key).get_summary(),
      });
      const spin = Gtk.SpinButton.new_with_range(min, max, step);
      spin.set_value(settings.get_int(key));
      const refresh = () => {
        isRefreshing = true;
        spin.set_value(settings.get_int(key));
        isRefreshing = false;
      };
      refreshHandlers[key] = refresh;
      spin.connect('notify::value', (w) => {
        if (isRefreshing)
          return;
        settings.set_int(key, w.get_value_as_int());
        scheduleReload();
      });
      spin.set_valign(Gtk.Align.CENTER);
      row.add_suffix(spin);
      group.add(row);
    };

    const addSpinDoubleRow = (group, key, min, max, step) => {
      const row = new Adw.ActionRow({
        title: settings.settings_schema.get_key(key).get_summary(),
      });
      const spin = Gtk.SpinButton.new_with_range(min, max, step);
      spin.set_value(settings.get_double(key));
      const refresh = () => {
        isRefreshing = true;
        spin.set_value(settings.get_double(key));
        isRefreshing = false;
      };
      refreshHandlers[key] = refresh;
      spin.connect('notify::value', (w) => {
        if (isRefreshing)
          return;
        settings.set_double(key, w.get_value());
        scheduleReload();
      });
      spin.set_valign(Gtk.Align.CENTER);
      row.add_suffix(spin);
      group.add(row);
    };

    const addComboRow = (group, key, options, labels, subtitle = null) => {
      const rowProps = {
        title: settings.settings_schema.get_key(key).get_summary(),
      };
      if (subtitle)
        rowProps.subtitle = subtitle;

      const row = new Adw.ActionRow(rowProps);
      const combo = new Gtk.ComboBoxText();
      const normalizeStringValue = (value) => {
        if (typeof value !== 'string')
          return value;
        if (value.length >= 2 && value.startsWith("'") && value.endsWith("'"))
          return value.slice(1, -1);
        return value;
      };
      for (let i = 0; i < options.length; i++)
        combo.append(options[i], labels[i]);
      const initialIndex = options.indexOf(normalizeStringValue(settings.get_string(key)));
      combo.set_active(initialIndex >= 0 ? initialIndex : 0);
      const refresh = () => {
        isRefreshing = true;
        const current = normalizeStringValue(settings.get_string(key));
        const index = options.indexOf(current);
        if (index >= 0)
          combo.set_active(index);
        isRefreshing = false;
      };
      refreshHandlers[key] = refresh;
      combo.connect('changed', (w) => {
        if (isRefreshing)
          return;
        settings.set_string(key, options[w.get_active()]);
        scheduleReload();
      });
      combo.set_valign(Gtk.Align.CENTER);
      row.add_suffix(combo);
      group.add(row);
    };

    const addColorRow = (group, key) => {
      const row = new Adw.ActionRow({
        title: settings.settings_schema.get_key(key).get_summary(),
      });
      
      const colorButton = new Gtk.ColorDialogButton();
      const dialog = new Gtk.ColorDialog();
      colorButton.set_dialog(dialog);
      colorButton.set_valign(Gtk.Align.CENTER);

      let isUpdating = false;

      const updatePickerVisuals = (hex) => {
          isUpdating = true;
          const rgba = new Gdk.RGBA();
          if (hex && hex.startsWith('#')) {
            rgba.parse(hex);
          } else {
            rgba.parse('#ffffff');
          }
          colorButton.set_rgba(rgba);
          isUpdating = false;
      };

      // Initial load
      updatePickerVisuals(settings.get_string(key));

      const refresh = () => {
        isRefreshing = true;
        updatePickerVisuals(settings.get_string(key));
        isRefreshing = false;
      };
      refreshHandlers[key] = refresh;

      colorButton.connect('notify::rgba', (btn) => {
        if (isUpdating || isRefreshing) return;
        
        const c = btn.get_rgba();
        const toHex = (v) => {
          const hex = Math.round(v * 255).toString(16);
          return hex.length === 1 ? '0' + hex : hex;
        };
        const hexString = `#${toHex(c.red)}${toHex(c.green)}${toHex(c.blue)}`;
        settings.set_string(key, hexString);
        scheduleReload();
      });

      const resetButton = new Gtk.Button({
        icon_name: 'edit-clear-symbolic',
        tooltip_text: _('Reset to system default'),
        valign: Gtk.Align.CENTER,
      });
      resetButton.add_css_class('flat');
      
      resetButton.connect('clicked', () => {
          updatePickerVisuals(''); // Set to white visually
          settings.set_string(key, '');
          scheduleReload();
      });

      row.add_suffix(colorButton);
      row.add_suffix(resetButton);
      group.add(row);
    };

    const addSwitchRow = (group, key, subtitle = null) => {
      const rowProps = {
        title: settings.settings_schema.get_key(key).get_summary(),
      };
      if (subtitle)
        rowProps.subtitle = subtitle;

      const row = new Adw.ActionRow(rowProps);
      const switchWidget = new Gtk.Switch();
      switchWidget.set_active(settings.get_boolean(key));
      const refresh = () => {
        isRefreshing = true;
        switchWidget.set_active(settings.get_boolean(key));
        isRefreshing = false;
      };
      refreshHandlers[key] = refresh;
      switchWidget.connect('notify::active', (w) => {
        if (isRefreshing)
          return;
        settings.set_boolean(key, w.get_active());
        scheduleReload();
      });
      switchWidget.set_valign(Gtk.Align.CENTER);
      row.add_suffix(switchWidget);
      group.add(row);
    };

    const resetKeysToDefaults = (keys) => {
      keys.forEach((key) => {
        settings.reset(key);
        if (refreshHandlers[key])
          refreshHandlers[key]();
      });
      scheduleReload();
    };

    const resetAllToDefaults = () => {
      const keys = settings.settings_schema.list_keys();
      keys.forEach((key) => {
        settings.reset(key);
        if (refreshHandlers[key])
          refreshHandlers[key]();
      });
      scheduleReload();
    };

    const appsPage = new Adw.PreferencesPage({
      title: _('Apps'),
      icon_name: 'view-grid-symbolic',
    });

    const foldersPage = new Adw.PreferencesPage({
      title: _('Folders'),
      icon_name: 'folder-symbolic',
    });

    // Grid layout settings
    const gridGroup = new Adw.PreferencesGroup({
      title: _('Grid layout'),
    });
    addSpinIntRow(gridGroup, 'appgrid-max-rows', 1, 20, 1);
    addSpinIntRow(gridGroup, 'appgrid-max-columns', 1, 20, 1);
    addSpinIntRow(gridGroup, 'appgrid-icon-size', 32, 256, 1);
    addSpinIntRow(gridGroup, 'side-padding', -128, 256, 1);

    // Label appearance
    const labelsGroup = new Adw.PreferencesGroup({
      title: _('Labels'),
    });
    addSpinDoubleRow(labelsGroup, 'app-icon-font-size', 0, 48, 0.1);
    addColorRow(labelsGroup, 'label-color');
    addColorRow(labelsGroup, 'label-shadow-color');
    addComboRow(
      labelsGroup,
      'label-style',
      [
        '',
        'font-weight: normal;',
        'font-weight: normal; text-shadow: 2px 3px 3px #000000;',
        'font-weight: bold;',
        'font-weight: bold; text-shadow: 2px 3px 3px #000000;',
      ],
      [
        _('System default'),
        _('Normal'),
        _('Normal with Shadow'),
        _('Bold'),
        _('Bold with Shadow'),
      ],
    );

    const appTilesGroup = new Adw.PreferencesGroup({
      title: _('App tiles'),
    });
    addSwitchRow(
      appTilesGroup,
      'app-hover-tile-enabled',
      _('Hover tile styling is best-effort and can depend on your GNOME Shell theme and version.')
    );
    addColorRow(appTilesGroup, 'app-hover-tile-background-color');
    addSpinDoubleRow(appTilesGroup, 'app-hover-tile-background-opacity', 0, 1, 0.01);
    addColorRow(appTilesGroup, 'app-hover-tile-border-color');
    addSpinIntRow(appTilesGroup, 'app-hover-tile-border-radius', 0, 64, 1);

    // Background appearance
    const backgroundGroup = new Adw.PreferencesGroup({
      title: _('Background'),
    });
    addComboRow(
      backgroundGroup,
      'appgrid-background-mode',
      [
        'system',
        'solid-color',
        'gradient',
      ],
      [
        _('System default'),
        _('Solid color'),
        _('Gradient'),
      ],
      _('Background overrides are best-effort and can depend on your GNOME Shell theme and version.')
    );
    addColorRow(backgroundGroup, 'appgrid-background-color');
    addComboRow(
      backgroundGroup,
      'appgrid-gradient-type',
      [
        'linear-vertical',
        'linear-horizontal',
      ],
      [
        _('Linear (vertical)'),
        _('Linear (horizontal)'),
      ],
    );
    addColorRow(backgroundGroup, 'appgrid-gradient-secondary-color');

    // Animation timings
    const animationsGroup = new Adw.PreferencesGroup({
      title: _('Animations'),
    });
    addSpinIntRow(animationsGroup, 'open-animation-time', 1, 10000, 1);
    addSpinIntRow(animationsGroup, 'page-switch-animation-time', 1, 10000, 1);

    // Folders: layout and popup settings split into clear groups
    const folderLayoutGroup = new Adw.PreferencesGroup({
      title: _('Folder layout'),
    });
    addSpinIntRow(folderLayoutGroup, 'folder-max-rows', 1, 20, 1);
    addSpinIntRow(folderLayoutGroup, 'folder-max-columns', 1, 20, 1);
    addSpinIntRow(folderLayoutGroup, 'folder-icon-size', 32, 256, 1);
    addSpinIntRow(folderLayoutGroup, 'folder-item-spacing', 40, 150, 2);
    addSpinIntRow(folderLayoutGroup, 'folder-item-height-offset', 30, 120, 2);

    const folderHeaderGroup = new Adw.PreferencesGroup({
      title: _('Folder header'),
    });
    addSwitchRow(folderHeaderGroup, 'hide-folder-title');

    const folderLabelsGroup = new Adw.PreferencesGroup({
      title: _('Folder labels'),
    });
    addSpinDoubleRow(folderLabelsGroup, 'folder-icon-font-size', 0, 48, 0.1);

    const folderPopupGroup = new Adw.PreferencesGroup({
      title: _('Folder popup'),
    });
    addSpinIntRow(folderPopupGroup, 'folder-popup-width', 400, 800, 10);
    addSpinIntRow(folderPopupGroup, 'folder-popup-height-offset', 50, 300, 5);
    addSpinIntRow(folderPopupGroup, 'folder-side-padding', -128, 256, 2);
    addColorRow(folderPopupGroup, 'folder-popup-background-color');
    addSpinDoubleRow(folderPopupGroup, 'folder-popup-background-opacity', 0, 1, 0.01);
    addColorRow(folderPopupGroup, 'folder-popup-border-color');
    addSpinIntRow(folderPopupGroup, 'folder-popup-border-radius', 0, 64, 1);

    const folderTileGroup = new Adw.PreferencesGroup({
      title: _('Folder tile'),
    });
    addColorRow(folderTileGroup, 'folder-tile-background-color');
    addSpinDoubleRow(folderTileGroup, 'folder-tile-background-opacity', 0, 1, 0.01);
    addColorRow(folderTileGroup, 'folder-tile-border-color');
    addSpinIntRow(folderTileGroup, 'folder-tile-border-radius', 0, 64, 1);

    const appsKeys = [
      'appgrid-max-rows',
      'appgrid-max-columns',
      'appgrid-icon-size',
      'side-padding',
      'app-icon-font-size',
      'label-color',
      'label-shadow-color',
      'label-style',
      'app-hover-tile-enabled',
      'app-hover-tile-background-color',
      'app-hover-tile-background-opacity',
      'app-hover-tile-border-color',
      'app-hover-tile-border-radius',
      'open-animation-time',
      'page-switch-animation-time',
      'appgrid-background-mode',
      'appgrid-background-color',
      'appgrid-gradient-type',
      'appgrid-gradient-secondary-color',
    ];

    const folderKeys = [
      'folder-max-rows',
      'folder-max-columns',
      'folder-icon-size',
      'folder-item-spacing',
      'folder-item-height-offset',
      'hide-folder-title',
      'folder-icon-font-size',
      'folder-popup-width',
      'folder-popup-height-offset',
      'folder-side-padding',
      'folder-popup-background-color',
      'folder-popup-background-opacity',
      'folder-popup-border-color',
      'folder-popup-border-radius',
      'folder-tile-background-color',
      'folder-tile-background-opacity',
      'folder-tile-border-color',
      'folder-tile-border-radius',
    ];

    const appsResetGroup = new Adw.PreferencesGroup({
      title: _('Reset'),
    });
    const appsResetRow = new Adw.ActionRow({
      title: _('Reset Apps settings'),
      subtitle: _('Resets all Apps settings of this extension to their default values.'),
    });
    const appsResetButton = new Gtk.Button({
      label: _('Reset'),
      valign: Gtk.Align.CENTER,
    });
    appsResetButton.add_css_class('destructive-action');
    appsResetButton.connect('clicked', () => {
      resetKeysToDefaults(appsKeys);
    });
    appsResetRow.add_suffix(appsResetButton);
    appsResetRow.set_activatable_widget(appsResetButton);
    appsResetGroup.add(appsResetRow);

    const resetAllRow = new Adw.ActionRow({
      title: _('Reset all settings'),
      subtitle: _('Resets all App Grid Tuner settings (Apps and Folders) to their default values.'),
    });
    const resetAllButton = new Gtk.Button({
      label: _('Reset All'),
      valign: Gtk.Align.CENTER,
    });
    resetAllButton.add_css_class('destructive-action');
    resetAllButton.connect('clicked', () => {
      resetAllToDefaults();
    });
    resetAllRow.add_suffix(resetAllButton);
    resetAllRow.set_activatable_widget(resetAllButton);
    appsResetGroup.add(resetAllRow);

    const foldersResetGroup = new Adw.PreferencesGroup({
      title: _('Reset'),
    });
    const foldersResetRow = new Adw.ActionRow({
      title: _('Reset Folders settings'),
      subtitle: _('Resets all Folders settings of this extension to their default values.'),
    });
    const foldersResetButton = new Gtk.Button({
      label: _('Reset'),
      valign: Gtk.Align.CENTER,
    });
    foldersResetButton.add_css_class('destructive-action');
    foldersResetButton.connect('clicked', () => {
      resetKeysToDefaults(folderKeys);
    });
    foldersResetRow.add_suffix(foldersResetButton);
    foldersResetRow.set_activatable_widget(foldersResetButton);
    foldersResetGroup.add(foldersResetRow);

    appsPage.add(gridGroup);
    appsPage.add(labelsGroup);
    appsPage.add(appTilesGroup);
    appsPage.add(backgroundGroup);
    appsPage.add(animationsGroup);
    appsPage.add(appsResetGroup);
    foldersPage.add(folderLayoutGroup);
    foldersPage.add(folderHeaderGroup);
    foldersPage.add(folderLabelsGroup);
    foldersPage.add(folderPopupGroup);
    foldersPage.add(folderTileGroup);
    foldersPage.add(foldersResetGroup);

    window.connect('close-request', () => {
      if (reloadSourceId) {
        GLib.Source.remove(reloadSourceId);
        reloadSourceId = null;
      }
      return false;
    });

    window.add(appsPage);
    window.add(foldersPage);
    window.set_default_size(700, 580);
  }
}
