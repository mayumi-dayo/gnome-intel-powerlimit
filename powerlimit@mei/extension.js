import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const SCRIPT_PATH = '/usr/local/bin/powerlimit.sh';
const PKEXEC_PATH = '/usr/bin/pkexec';
const ENV_PATH = '/usr/bin/env';

const MENU_OPTIONS = [
    {choice: '1', label: '3W'},
    {choice: '2', label: '6W'},
    {choice: '3', label: '12W'},
    {choice: '4', label: '15W'},
    {choice: '5', label: '20W'},
    {choice: '6', label: '25W'},
    {choice: '7', label: '30W'},
    {choice: '8', label: '35W'},
    {choice: '9', label: '40W'},
    {choice: '10', label: 'Enable Turbo Boost'},
    {choice: '11', label: 'Disable Turbo Boost'},
];

const PowerLimitIndicator = GObject.registerClass(
class PowerLimitIndicator extends PanelMenu.Button {
    _init(extensionPath) {
        super._init(0.0, 'Power Limit');

        this._busy = false;
        this._items = [];

        const icon = new St.Icon({
            gicon: Gio.icon_new_for_string(GLib.build_filenamev([extensionPath, 'icon.png'])),
            style_class: 'system-status-icon',
        });
        this.add_child(icon);

        for (const option of MENU_OPTIONS) {
            const item = new PopupMenu.PopupMenuItem(option.label);
            item.connect('activate', () => {
                this._runChoice(option.choice, option.label);
            });
            this.menu.addMenuItem(item);
            this._items.push(item);
        }
    }

    _setBusy(busy) {
        this._busy = busy;

        for (const item of this._items)
            item.sensitive = !busy;
    }

    _runChoice(choice, label) {
        if (this._busy)
            return;

        if (!GLib.file_test(SCRIPT_PATH, GLib.FileTest.EXISTS)) {
            Main.notify('Power Limit', `${SCRIPT_PATH} is missing`);
            return;
        }

        this._setBusy(true);

        let process;

        try {
            process = Gio.Subprocess.new(
                [PKEXEC_PATH, ENV_PATH, 'KDIALOG_BIN=', SCRIPT_PATH, choice],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE
            );
        } catch (error) {
            this._setBusy(false);
            Main.notify('Power Limit', error.message);
            return;
        }

        process.communicate_utf8_async(null, null, (proc, result) => {
            try {
                const [, stdout, stderr] = proc.communicate_utf8_finish(result);

                if (proc.get_successful()) {
                    Main.notify('Power Limit', `Applied ${label}`);
                } else {
                    const details = (stderr || stdout || 'The command failed').trim();
                    Main.notify('Power Limit', details);
                }
            } catch (error) {
                Main.notify('Power Limit', error.message);
            } finally {
                this._setBusy(false);
            }
        });
    }
});

export default class PowerLimitExtension extends Extension {
    enable() {
        this._indicator = new PowerLimitIndicator(this.path);
        Main.panel.addToStatusArea(this.uuid, this._indicator);
    }

    disable() {
        this._indicator?.destroy();
        this._indicator = null;
    }
}