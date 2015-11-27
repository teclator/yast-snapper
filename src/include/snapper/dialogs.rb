# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006-2015 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

# File:	include/snapper/dialogs.ycp
# Package:	Configuration of snapper
# Summary:	Dialogs definitions
# Authors:	Jiri Suchomel <jsuchome@suse.cz>

module Yast

  module SnapperDialogsInclude

    include Yast::Logger

    def initialize_snapper_dialogs(include_target)
      Yast.import "UI"

      textdomain "snapper"

      Yast.import "Confirm"
      Yast.import "FileUtils"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "Snapper"
      Yast.import "String"

      Yast.include include_target, "snapper/helps.rb"

    end


    def timestring(t)
      return t.strftime("%F %T")
    end

    # transform userdata from widget to map
    def get_userdata(id)
      return Snapper.string_to_userdata(UI.QueryWidget(Id(id), :Value))
    end


    # generate list of items for Cleanup combo box
    def cleanup_items(current)
      Builtins.maplist(["timeline", "number", ""]) do |cleanup|
        Item(Id(cleanup), cleanup, cleanup == current)
      end
    end


    # compare editable parts of snapshot maps
    def snapshot_modified(orig, new)
      new.map do |k,v|
        return true if orig[k] != v
      end
      false
    end

    # grouped enable condition based on snapshot presence for modification widgets
    def enable_buttons(buttons, condition)
      buttons.map do |b|
        UI.ChangeWidget(Id(b), :Enabled, condition) 
      end
    end


    # Popup for modification of existing snapshot
    # @return true if new snapshot was created
    def ModifySnapshotPopup(snapshot)
      modified = false
      num = snapshot["num"] || 0
      pre_num = snapshot["pre_num"] || num
      type = snapshot["type"] || :none

      pre_index = Snapper.id2index[pre_num] || 0
      pre_snapshot = Snapper.snapshots[pre_index] || {}

      if type != :POST
        cont = VBox(
          # popup label, %{num} is number
          Label(_("Modify Snapshot %{num}") % { :num => num }),
          snapshot_term("", snapshot)
        )
      else
        cont = VBox(
          # popup label, %{pre} and %{post} are numbers
          Label(_("Modify Snapshot %{pre} and %{post}") % { :pre => pre_num, :post => num }),
          # label
          Left(Label(_("Pre (%{pre})") % { :pre => pre_num })),
          snapshot_term("pre_", pre_snapshot),
          VSpacing(),
          # label
          Left(Label(_("Post (%{post})") % { :post => num })),
          snapshot_term("", snapshot)
        )
      end

      open_modify_dialog(cont)

      pre_args = {}

      while true
        ret = UI.UserInput
        args = {
          "num"         => num,
          "description" => UI.QueryWidget(Id("description"), :Value),
          "cleanup"     => UI.QueryWidget(Id("cleanup"), :Value),
          "userdata"    => get_userdata("userdata")
        }
        if type == :POST
          pre_args = {
            "num"         => pre_num,
            "description" => UI.QueryWidget(Id("pre_description"), :Value),
            "cleanup"     => UI.QueryWidget(Id("pre_cleanup"), :Value),
            "userdata"    => get_userdata("pre_userdata")
          }
        end
        break if ret == :ok || ret == :cancel
      end
      UI.CloseDialog
      if ret == :ok
        if snapshot_modified(snapshot, args)
          modified = Snapper.ModifySnapshot(args)
        end
        if type == :POST && snapshot_modified(pre_snapshot, pre_args)
          modified = Snapper.ModifySnapshot(pre_args) || modified
        end
      end

      modified
    end


    # Popup for creating new snapshot
    # @return true if new snapshot was created
    def CreateSnapshotPopup(pre_snapshots)
      created = false
      pre_items = pre_snapshots.map do |s|
        Item(Id(s), s.to_s)
      end

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1),
          VBox(
            VSpacing(0.5),
            HSpacing(65),
            # popup label
            Label(_("Create New Snapshot")),
            # text entry label
            InputField(Id("description"), Opt(:hstretch), _("Description"), ""),
            RadioButtonGroup(
              Id(:rb_type),
              Left(
                HVSquash(
                  VBox(
                    Left(
                      RadioButton(
                        Id("single"),
                        Opt(:notify),
                        # radio button label
                        _("Single snapshot"),
                        true
                      )
                    ),
                    Left(
                      RadioButton(
                        Id("pre"),
                        Opt(:notify),
                        # radio button label
                        _("Pre"),
                        false
                      )
                    ),
                    VBox(
                      Left(
                        RadioButton(
                          Id("post"),
                          Opt(:notify),
                          # radio button label, snapshot selection will follow
                          _("Post, paired with:"),
                          false
                        )
                      ),
                      HBox(
                        HSpacing(2),
                        Left(
                          ComboBox(Id(:pre_list), Opt(:notify), "", pre_items)
                        )
                      )
                    )
                  )
                )
              )
            ),
            # text entry label
            InputField(Id("userdata"), Opt(:hstretch), _("User data"), ""),
            # text entry label
            ComboBox(
              Id("cleanup"),
              Opt(:editable, :hstretch),
              _("Cleanup algorithm"),
              cleanup_items("")
            ),
            VSpacing(0.5),
            ButtonBox(
              PushButton(Id(:ok), Label.OKButton),
              PushButton(Id(:cancel), Label.CancelButton)
            ),
            VSpacing(0.5)
          ),
          HSpacing(1)
        )
      )

      UI.ChangeWidget(
        Id("post"),
        :Enabled,
      	!pre_items.empty?
      )
      UI.ChangeWidget(
        Id(:pre_list),
        :Enabled,
      	!pre_items.empty?
      )

      ret = nil
      args = {}
      while true
        ret = UI.UserInput
        args = {
          "type"        => UI.QueryWidget(Id(:rb_type), :Value),
          "description" => UI.QueryWidget(Id("description"), :Value),
          "pre"         => UI.QueryWidget(Id(:pre_list), :Value),
          "cleanup"     => UI.QueryWidget(Id("cleanup"), :Value),
          "userdata"    => get_userdata("userdata")
        }
        break if ret == :ok || ret == :cancel
      end
      UI.CloseDialog
      created = Snapper.CreateSnapshot(args) if ret == :ok
      created
    end

    
    # Popup for deleting existing snapshot
    # @return true if snapshot was deleted
    def DeleteSnapshotPopup(snapshot)
      num = snapshot["num"] || 0
      pre_num = snapshot["pre_num"] || 0
      type = snapshot["type"]

      if type != :POST
        # yes/no popup question
        if Popup.YesNo(_("Really delete snapshot %{num}?") % { :num => num })
          return Snapper.DeleteSnapshot([ num ])
        end
      else
        # yes/no popup question
        if Popup.YesNo(_("Really delete snapshots %{pre} and %{post}?") %
                       { :pre => pre_num, :post => num })
          return Snapper.DeleteSnapshot([ pre_num, num ])
        end
      end
      false
    end


    # Summary dialog
    # @return dialog result
    def SummaryDialog
      # summary dialog caption
      caption = _("Snapshots")

      # update list of snapshots
      Wizard.SetContentsButtons(
        caption,
        snapshots_table,
        Ops.get_string(@HELPS, "summary", ""),
        Label.BackButton,
        Label.CloseButton
      )
      Wizard.HideBackButton
      Wizard.HideAbortButton

      UI.SetFocus(Id(:snapshots_table))
      enable_buttons([:show, :modify, :delete], !get_snapshot_items.empty?)
      enable_buttons([:configs], Snapper.configs.size > 1)

      ret = nil
      while true
        ret = UI.UserInput

        selected = UI.QueryWidget(Id(:snapshots_table), :CurrentItem)

        if ret == :abort || ret == :cancel || ret == :back
          if ReallyAbort()
            break
          else
            next
          end

        elsif ret == :show
          if Ops.get(Snapper.snapshots, [selected, "type"]) == :PRE
            # popup message
            Popup.Message(
              _(
                "This 'Pre' snapshot is not paired with any 'Post' one yet.\nShowing differences is not possible."
              )
            )
            next
          end
          # `POST snapshot is selected from the pair
          Snapper.selected_snapshot = Ops.get(Snapper.snapshots, selected, {})
          break

        elsif ret == :configs
          config = Convert.to_string(UI.QueryWidget(Id(ret), :Value))
          if config != Snapper.current_config
            Snapper.current_config = config
            update_snapshots
            next
          end

        elsif ret == :create
          if CreateSnapshotPopup(pre_lonely_snapshots)
            update_snapshots
            next
          end

        elsif ret == :modify
          if ModifySnapshotPopup(Ops.get(Snapper.snapshots, selected, {}))
            update_snapshots
            next
          end

        elsif ret == :delete
          if DeleteSnapshotPopup(Ops.get(Snapper.snapshots, selected, {}))
            update_snapshots
            next
          end

        elsif ret == :next
          break
        elsif ret == :snapshots_table
          enable_buttons([:show, :modify], selected.size == 1)
          enable_buttons([:delete], selected.size >= 1)
        else
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end

      end

      deep_copy(ret)
    end


    def generate_ui_file_tree(subtree)
      return subtree.children.map do |file|
        Item(Id(file.fullname), term(:icon, file.icon), file.name, false,
             generate_ui_file_tree(file))
      end
    end


    def format_diff(diff, textmode)
      lines = Builtins.splitstring(String.EscapeTags(diff), "\n")
      if !textmode
        # colorize diff output
        lines.map! do |line|
          case line[0]
          when "+"
            line = "<font color=blue>#{line}</font>"
          when "-"
            line = "<font color=red>#{line}</font>"
          end
          line
        end
      end
      ret = lines.join("<br>")
      if !textmode
        # show fixed font in diff
        ret = "<pre>" + ret + "</pre>"
      end
      return ret
    end


    # @return dialog result
    def ShowDialog

      # dialog caption
      caption = _("Selected Snapshot Overview")

      display_info = UI.GetDisplayInfo
      textmode = Ops.get_boolean(display_info, "TextMode", false)

      previous_filename = ""
      current_filename = ""
      current_file = nil

      snapshot = deep_copy(Snapper.selected_snapshot)
      snapshot_num = Ops.get_integer(snapshot, "num", 0)

      pre_num = Ops.get_integer(snapshot, "pre_num", snapshot_num)
      pre_index = Ops.get(Snapper.id2index, pre_num, 0)
      description = Ops.get_string(
        Snapper.snapshots,
        [pre_index, "description"],
        ""
      )
      pre_date = timestring(Snapper.snapshots[pre_index]["date"])
      date = timestring(snapshot["date"])
      type = Ops.get_symbol(snapshot, "type", :NONE)
      combo_items = []
      Snapper.snapshots.map do |s|
        id = s["num"] || 0
        if id != snapshot_num
          # '%1: %2' means 'ID: description', adapt the order if necessary
          combo_items << Item(
            Id(id),
            Builtins.sformat(
              _("%1: %2"),
              id,
              Ops.get_string(s, "description", "")
            )
          )
        end
      end

      from = snapshot_num
      to = 0 # current system
      if Ops.get_symbol(snapshot, "type", :NONE) == :POST
        from = Ops.get_integer(snapshot, "pre_num", 0)
        to = snapshot_num
      elsif Ops.get_symbol(snapshot, "type", :NONE) == :PRE
        to = Ops.get_integer(snapshot, "post_num", 0)
      end

      # busy popup message
      Popup.ShowFeedback("", _("Calculating changed files..."))
      files_tree = Snapper.ReadModifiedFilesTree(from, to)
      Popup.ClearFeedback()

      snapshot_name = Builtins.tostring(snapshot_num)

      # helper function: show the specific modification between snapshots
      show_file_modification = lambda do |file, from2, to2|
        content = VBox()
        # busy popup message
        Popup.ShowFeedback("", _("Calculating file modifications..."))
        modification = Snapper.GetFileModification(file.fullname, from2, to2)
        Popup.ClearFeedback
        status = Ops.get_list(modification, "status", [])
        if Builtins.contains(status, "created")
          # label
          content = Builtins.add(
            content,
            Left(Label(_("New file was created.")))
          )
        elsif Builtins.contains(status, "removed")
          # label
          content = Builtins.add(content, Left(Label(_("File was removed."))))
        elsif Builtins.contains(status, "no_change")
          # label
          content = Builtins.add(
            content,
            Left(Label(_("File content was not changed.")))
          )
        elsif Builtins.contains(status, "none")
          # label
          content = Builtins.add(
            content,
            Left(Label(_("File does not exist in either snapshot.")))
          )
        elsif Builtins.contains(status, "diff")
          # label
          content = Builtins.add(
            content,
            Left(Label(_("File content was modified.")))
          )
        end
        if Builtins.contains(status, "mode")
          content = Builtins.add(
            content,
            Left(
              Label(
                # text label, %1, %2 are file modes (like '-rw-r--r--')
                Builtins.sformat(
                  _("File mode was changed from '%1' to '%2'."),
                  Ops.get_string(modification, "mode1", ""),
                  Ops.get_string(modification, "mode2", "")
                )
              )
            )
          )
        end
        if Builtins.contains(status, "user")
          content = Builtins.add(
            content,
            Left(
              Label(
                # text label, %1, %2 are user names
                Builtins.sformat(
                  _("File user ownership was changed from '%1' to '%2'."),
                  Ops.get_string(modification, "user1", ""),
                  Ops.get_string(modification, "user2", "")
                )
              )
            )
          )
        end
        if Builtins.contains(status, "group")
          # label
          content = Builtins.add(
            content,
            Left(
              Label(
                # text label, %1, %2 are group names
                Builtins.sformat(
                  _("File group ownership was changed from '%1' to '%2'."),
                  Ops.get_string(modification, "group1", ""),
                  Ops.get_string(modification, "group2", "")
                )
              )
            )
          )
        end

        if Builtins.haskey(modification, "diff")
          content = Builtins.add(content, RichText(Id(:diff),
            format_diff(Ops.get_string(modification, "diff", ""), textmode)))
        else
          content = Builtins.add(content, VStretch())
        end

        # button label
        restore_label = _("R&estore from First")
        # button label
        restore_label_single = _("Restore")

        if file.created?
          restore_label = Label.RemoveButton
          restore_label_single = Label.RemoveButton
        end

        UI.ReplaceWidget(
          Id(:diff_content),
          HBox(
            HSpacing(0.5),
            VBox(
              content,
              VSquash(
                HBox(
                  HStretch(),
                  type == :SINGLE ?
                    Empty() :
                    PushButton(Id(:restore_pre), restore_label),
                  PushButton(
                    Id(:restore),
                    type == :SINGLE ?
                      restore_label_single :
                      _("Res&tore from Second")
                  )
                )
              )
            ),
            HSpacing(0.5)
          )
        )
        if type != :SINGLE && file.deleted?
          # file removed in 2nd snapshot cannot be restored from that snapshot
          UI.ChangeWidget(Id(:restore), :Enabled, false)
        end

        nil
      end


      # create the term for selected file
      set_entry_term = lambda do
        if current_file && current_file.status != 0
          if type == :SINGLE
            UI.ReplaceWidget(
              Id(:diff_chooser),
              HBox(
                HSpacing(0.5),
                VBox(
                  VSpacing(0.2),
                  RadioButtonGroup(
                    Id(:rd),
                    Left(
                      HVSquash(
                        VBox(
                          Left(
                            RadioButton(
                              Id(:diff_snapshot),
                              Opt(:notify),
                              # radio button label
                              _(
                                "Show the difference between snapshot and current system"
                              ),
                              true
                            )
                          ),
                          VBox(
                            Left(
                              RadioButton(
                                Id(:diff_arbitrary),
                                Opt(:notify),
                                # radio button label, snapshot selection will follow
                                _(
                                  "Show the difference between current and selected snapshot:"
                                ),
                                false
                              )
                            ),
                            HBox(
                              HSpacing(2),
                              # FIXME without label, there's no shortcut!
                              Left(
                                ComboBox(
                                  Id(:selection_snapshots),
                                  Opt(:notify),
                                  "",
                                  combo_items
                                )
                              )
                            )
                          )
                        )
                      )
                    )
                  ),
                  VSpacing()
                ),
                HSpacing(0.5)
              )
            )
            show_file_modification.call(current_file, snapshot_num, 0)
            UI.ChangeWidget(Id(:selection_snapshots), :Enabled, false)
          else
            UI.ReplaceWidget(
              Id(:diff_chooser),
              HBox(
                HSpacing(0.5),
                VBox(
                  VSpacing(0.2),
                  RadioButtonGroup(
                    Id(:rd),
                    Left(
                      HVSquash(
                        VBox(
                          Left(
                            RadioButton(
                              Id(:diff_snapshot),
                              Opt(:notify),
                              # radio button label
                              _(
                                "Show the difference between first and second snapshot"
                              ),
                              true
                            )
                          ),
                          Left(
                            RadioButton(
                              Id(:diff_pre_current),
                              Opt(:notify),
                              # radio button label
                              _(
                                "Show the difference between first snapshot and current system"
                              ),
                              false
                            )
                          ),
                          Left(
                            RadioButton(
                              Id(:diff_post_current),
                              Opt(:notify),
                              # radio button label
                              _(
                                "Show the difference between second snapshot and current system"
                              ),
                              false
                            )
                          )
                        )
                      )
                    )
                  ),
                  VSpacing()
                ),
                HSpacing(0.5)
              )
            )
            show_file_modification.call(current_file, pre_num, snapshot_num)
          end
        else
          UI.ReplaceWidget(Id(:diff_chooser), VBox(VStretch()))
          UI.ReplaceWidget(Id(:diff_content), HBox(HStretch()))
        end

        nil
      end

      if type == :SINGLE
        tree_label = "%{num}" % { :num => snapshot_num }
        date_widget = HBox(
          # label, date string will follow at the end of line
          Label(Id(:date), _("Time of taking the snapshot:")),
          Right(Label(date))
        )
      else
        tree_label = "%{pre} && %{post}" % { :pre => pre_num, :post => snapshot_num }
        date_widget = VBox(
          HBox(
            # label, date string will follow at the end of line
            Label(Id(:pre_date), _("Time of taking the first snapshot:")),
            Right(Label(pre_date))
          ),
          HBox(
            # label, date string will follow at the end of line
            Label(Id(:post_date), _("Time of taking the second snapshot:")),
            Right(Label(date))
          )
        )
      end

      contents = HBox(
        HWeight(
          1,
          VBox(
            HBox(
              HSpacing(),
              ReplacePoint(
                Id(:reptree),
                VBox(Left(Label(Snapper.current_subvolume)), Tree(Id(:tree), tree_label, []))
              ),
              HSpacing()
            ),
            HBox(
              HSpacing(1.5),
              HStretch(),
              textmode ?
                # button label
                PushButton(Id(:open), Opt(:key_F6), _("&Open")) :
                Empty(),
              HSpacing(1.5)
            )
          )
        ),
        HWeight(
          2,
          VBox(
            Left(Label(Id(:desc), description)),
            VSquash(VWeight(1, VSquash(date_widget))),
            VWeight(
              2,
              Frame(
                "",
                HBox(
                  HSpacing(0.5),
                  VBox(
                    VSpacing(0.5),
                    VWeight(
                      1,
                      ReplacePoint(Id(:diff_chooser), VBox(VStretch()))
                    ),
                    VWeight(
                      4,
                      ReplacePoint(Id(:diff_content), HBox(HStretch()))
                    ),
                    VSpacing(0.5)
                  ),
                  HSpacing(0.5)
                )
              )
            )
          )
        )
      )

      # show the dialog contents with empty tree, compute items later
      Wizard.SetContentsButtons(
        caption,
        contents,
        type == :SINGLE ?
          Ops.get_string(@HELPS, "show_single", "") :
          Ops.get_string(@HELPS, "show_pair", ""),
        # button label
        Label.CancelButton,
        _("Restore Selected")
      )

      tree_items = generate_ui_file_tree(files_tree)

      if !tree_items.empty?
        UI.ReplaceWidget(
          Id(:reptree),
          VBox(
            Left(Label(Snapper.current_subvolume)),
            Tree(
              Id(:tree),
              Opt(:notify, :immediate, :multiSelection, :recursiveSelection),
              tree_label,
              tree_items
            )
          )
        )
        # no item is selected
        UI.ChangeWidget(:tree, :CurrentItem, nil)
      end

      current_filename = ""

      set_entry_term.call

      UI.SetFocus(Id(:tree)) if textmode

      ret = nil
      while true
        event = UI.WaitForEvent
        ret = Ops.get_symbol(event, "ID")

        previous_filename = current_filename
        current_filename = UI.QueryWidget(Id(:tree), :CurrentItem)

        if current_filename == nil
          current_filename = ""
        else
          current_filename.force_encoding(Encoding::ASCII_8BIT)
        end

        if current_filename.empty?
          current_file = nil
        else
          current_file = files_tree.find(current_filename)
        end

        # other tree events
        if ret == :tree
          # seems like tree widget emits 2 SelectionChanged events
          if current_filename != previous_filename
            set_entry_term.call
            UI.SetFocus(Id(:tree)) if textmode
          end

        elsif ret == :diff_snapshot
          if type == :SINGLE
            UI.ChangeWidget(Id(:selection_snapshots), :Enabled, false)
            show_file_modification.call(current_file, snapshot_num, 0)
          else
            show_file_modification.call(current_file, pre_num, snapshot_num)
          end

        elsif ret == :diff_arbitrary || ret == :selection_snapshots
          UI.ChangeWidget(Id(:selection_snapshots), :Enabled, true)
          selected_num = Convert.to_integer(
            UI.QueryWidget(Id(:selection_snapshots), :Value)
          )
          show_file_modification.call(current_file, pre_num, selected_num)

        elsif ret == :diff_pre_current
          show_file_modification.call(current_file, pre_num, 0)

        elsif ret == :diff_post_current
          show_file_modification.call(current_file, snapshot_num, 0)

        elsif ret == :abort || ret == :cancel || ret == :back
          break

        elsif (ret == :restore_pre || ret == :restore && type == :SINGLE) &&
            current_file.created?
          # yes/no question, %1 is file name, %2 is number
          if Popup.YesNo(
              Builtins.sformat(
                _(
                  "Do you want to delete the file\n" +
                    "\n" +
                    "%1\n" +
                    "\n" +
                    "from current system?"
                ),
                Snapper.GetFileFullPath(current_filename)
              )
            )
            Snapper.RestoreFiles(
              ret == :restore_pre ? pre_num : snapshot_num,
              [current_filename]
            )
          end
          next

        elsif ret == :restore_pre
          # yes/no question, %1 is file name, %2 is number
          if Popup.YesNo(
              Builtins.sformat(
                _(
                  "Do you want to copy the file\n" +
                    "\n" +
                    "%1\n" +
                    "\n" +
                    "from snapshot '%2' to current system?"
                ),
                Snapper.GetFileFullPath(current_filename),
                pre_num
              )
            )
            Snapper.RestoreFiles(pre_num, [current_filename])
          end
          next

        elsif ret == :restore
          # yes/no question, %1 is file name, %2 is number
          if Popup.YesNo(
              Builtins.sformat(
                _(
                  "Do you want to copy the file\n" +
                    "\n" +
                    "%1\n" +
                    "\n" +
                    "from snapshot '%2' to current system?"
                ),
                Snapper.GetFileFullPath(current_filename),
                snapshot_num
              )
            )
            Snapper.RestoreFiles(snapshot_num, [current_filename])
          end
          next

        elsif ret == :next

          filenames = UI.QueryWidget(Id(:tree), :SelectedItems)
          filenames.map!{ |filename| filename.force_encoding(Encoding::ASCII_8BIT) }

          # remove filenames not changed between the snapshots, e.g. /foo if
          # only /foo/bar changed
          filenames.delete_if { |filename| files_tree.find(filename[1..-1]).status == 0 }

          if filenames.empty?
            # popup message
            Popup.Message(_("No file was selected for restoring."))
            next
          end

          to_restore = filenames.map do |filename|
            String.EscapeTags(Snapper.prepend_subvolume(filename))
          end

          if Popup.AnyQuestionRichText(
               # popup headline
              _("Restoring files"),
              # popup message, %1 is snapshot number, %2 list of files
              Builtins.sformat(
                _(
                  "<p>These files will be restored from snapshot '%1':</p>\n" +
                    "<p>\n" +
                    "%2\n" +
                    "</p>\n" +
                    "<p>Files existing in original snapshot will be copied to current system.</p>\n" +
                    "<p>Files that did not exist in the snapshot will be deleted.</p>Are you sure?"
                ),
                pre_num,
                to_restore.join("<br>")
              ),
              60,
              20,
              Label.YesButton,
              Label.NoButton,
              :focus_no
            )
            Snapper.RestoreFiles(pre_num, filenames)
            break
          end
          next

        else
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end

      end

      deep_copy(ret)
    end


    private

    def ReallyAbort
      Popup.ReallyAbort(true)
    end


    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      return :abort if !Confirm.MustBeRoot

      Wizard.RestoreHelp(Ops.get_string(@HELPS, "read", ""))
      ret = Snapper.Init()
      ret ? :next : :abort
    end

    def open_modify_dialog(content)
      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1),
          VBox(
            VSpacing(0.5),
            HSpacing(65),
            content,
            VSpacing(0.5),
            ButtonBox(
              PushButton(Id(:ok), Label.OKButton),
              PushButton(Id(:cancel), Label.CancelButton)
            ),
            VSpacing(0.5)
          ),
          HSpacing(1)
        )
      )
    end

    def snapshot_term(prefix, data)
      data = deep_copy(data)
      HBox(
        HSpacing(),
        Frame(
          "",
          HBox(
            HSpacing(0.4),
            VBox(
              # text entry label
              InputField(
                Id(Ops.add(prefix, "description")),
                Opt(:hstretch),
                _("Description"),
                Ops.get_string(data, "description", "")
              ),
              # text entry label
              InputField(
                Id(Ops.add(prefix, "userdata")),
                Opt(:hstretch),
                _("User data"),
                Snapper.userdata_to_string(data["userdata"])
              ),
              Left(
                ComboBox(
                  Id(Ops.add(prefix, "cleanup")),
                  Opt(:editable, :hstretch),
                  # combo box label
                  _("Cleanup algorithm"),
                  cleanup_items(Ops.get_string(data, "cleanup", ""))
                )
              )
            ),
            HSpacing(0.4)
          )
        ),
        HSpacing()
      )
    end

    def update_snapshots
      # busy popup message
      Popup.ShowFeedback("", _("Reading list of snapshots..."))

      Snapper.ReadSnapshots()

      Popup.ClearFeedback

      snapshot_items = get_snapshot_items
      UI.ChangeWidget(Id(:snapshots_table), :Items, snapshot_items)
      selected = UI.QueryWidget(Id(:snapshots_table), :CurrentItem)
      enable_buttons([:modify, :show, :delete], !snapshot_items.empty?)
    end

    def get_snapshot_items
      snapshot_items = []

      Snapper.snapshots.each_with_index do |s,i|
        num = s["num"] || 0
        start_date = (num != 0) ? timestring(s["date"]) : ""
        end_date = ""
        userdata = Snapper.userdata_to_string(s["userdata"])
        desc = s["description"].to_s
        if s["type"] == :SINGLE
          type = _("Single")
        elsif s["type"] == :POST
          pre = s["pre_num"] || 0 # pre canot be 0
          index = Ops.get(Snapper.id2index, pre, -1)
          if pre == 0 || index == -1
            Builtins.y2warning(
              "something wrong - pre:%1, index:%2",
              pre,
              index
            )
            next
          end
          desc = Ops.get_string(Snapper.snapshots, [index, "description"], "")
          end_date = start_date
          start_date = timestring(Snapper.snapshots[index]["date"])
          num = "%{pre} & %{post}" % { :pre => pre, :post => num }
          type = _("Pre & Post")
        else
          # 0 means there's no post
          if s["post_num"].to_i == 0
            Builtins.y2milestone("pre snappshot %1 does not have post", num)
            type = _("Pre")
          else
            Builtins.y2milestone("skipping pre snapshot: %1", num)
            next
          end
        end
        snapshot_items << Item(Id(i), num, type, start_date, end_date, desc, userdata)
      end
      snapshot_items
    end

    def config_select
      HBox(
        # combo box label
        Label(_("Current Configuration")),
        ComboBox(Id(:configs), Opt(:notify), "", Builtins.maplist(Snapper.configs) do |config|
          Item(Id(config), config, config == Snapper.current_config)
        end),
        HStretch()
      )
    end

    def snapshots_table
      VBox(
        config_select,
        Table(
          Id(:snapshots_table),
          Opt(:notify, :keepSorting),
          Header(
            # table header
            _("ID"),
            _("Type"),
            _("Start Date"),
            _("End Date"),
            _("Description"),
            _("User Data")
          ),
          get_snapshot_items
        ),
        snapshots_table_footer
      )
    end

    def snapshots_table_footer
      HBox(
        # button label
        PushButton(Id(:show), Opt(:default), _("Show Changes")),
        PushButton(Id(:create), Label.CreateButton),
        # button label
        PushButton(Id(:modify), _("Modify")),
        PushButton(Id(:delete), Label.DeleteButton),
        HStretch()
      )
    end

    def selected_snapshots(selection)
      selection.map do |s|
        Snapper.snapshots[s]
      end
    end

    def pre_lonely_snapshots
      Snapper.snapshots.select {|s| (s["type"] == :PRE) && (s["post_num"].to_i == 0) }.map {|s| s["num"]}
    end

  end

end
