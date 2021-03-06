------------------------------------------------------------------------------
--                         Language Server Protocol                         --
--                                                                          --
--                     Copyright (C) 2018-2020, AdaCore                     --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------

with Ada.Containers.Hashed_Maps;

with Libadalang.Common;           use Libadalang.Common;
with Libadalang.Iterators;
with Libadalang.Sources;

package body LSP.Ada_File_Sets is

   -----------
   -- Clear --
   -----------

   procedure Clear (Self : in out Indexed_File_Set'Class) is
   begin
      Self.Files.Clear;
   end Clear;

   --------------
   -- Contains --
   --------------

   function Contains
     (Self : Indexed_File_Set'Class;
      File : GNATCOLL.VFS.Virtual_File) return Boolean is
   begin
      return Self.Files.Contains (File);
   end Contains;

   -------------------------------
   -- Get_Any_Symbol_Completion --
   -------------------------------

   procedure Get_Any_Symbol_Completion
     (Self   : Indexed_File_Set'Class;
      Prefix : VSS.Strings.Virtual_String;
      Limit  : Ada.Containers.Count_Type;
      Result : in out LSP.Ada_Completion_Sets.Completion_Map)
   is
      use type Ada.Containers.Count_Type;

      Cursor : Symbol_Maps.Cursor :=
        Self.All_Symbols.Ceiling (Prefix);
   begin
      while Symbol_Maps.Has_Element (Cursor)
        and Result.Length < Limit
      loop
         declare
            Value : constant VSS.Strings.Virtual_String :=
              Symbol_Maps.Key (Cursor);
         begin
            exit when not Value.Starts (Prefix);

            Result.Append_Invisible_Symbol
              (Value, Self.All_Symbols (Cursor).Original);

            Symbol_Maps.Next (Cursor);
         end;
      end loop;
   end Get_Any_Symbol_Completion;

   -------------
   -- Include --
   -------------

   procedure Include
     (Self : in out Indexed_File_Set'Class;
      File : GNATCOLL.VFS.Virtual_File) is
   begin
      Self.Files.Include (File);
   end Include;

   ----------------
   -- Index_File --
   ----------------

   procedure Index_File
     (Self : in out Indexed_File_Set'Class;
      File : GNATCOLL.VFS.Virtual_File;
      Unit : Libadalang.Analysis.Analysis_Unit)
   is

      package Symbol_Sets is new Ada.Containers.Hashed_Maps
        (Key_Type        => VSS.Strings.Virtual_String,
         Element_Type    => LSP.Types.LSP_String,
         Hash            => LSP.Ada_Completion_Sets.Hash,
         Equivalent_Keys => VSS.Strings."=",
         "="             => LSP.Types."=");

      Node       : Libadalang.Analysis.Ada_Node;
      Symbol_Set : Symbol_Sets.Map;  --  Unique symbols collection

      It         : Libadalang.Iterators.Traverse_Iterator'Class :=
        Libadalang.Iterators.Find
          (Unit.Root,
           Libadalang.Iterators.Kind_Is (Ada_Defining_Name));
   begin
      Symbol_Set.Reserve_Capacity (200);

      while It.Next (Node) loop
         declare
            Text : constant Wide_Wide_String :=
              Libadalang.Common.Text (Node.Token_End);

            Symbol    : constant LSP.Types.LSP_String :=
              LSP.Types.To_LSP_String (Text);

            Canonical : constant Symbolization_Result :=
              Libadalang.Sources.Canonicalize (Text);
         begin
            if Canonical.Success then
               Symbol_Set.Include
                 (VSS.Strings.To_Virtual_String (Canonical.Symbol), Symbol);
            end if;
         end;
      end loop;

      for Item in Symbol_Set.Iterate loop
         declare
            Canonical : constant VSS.Strings.Virtual_String :=
              Symbol_Sets.Key (Item);
            Inserted : Boolean;
            Cursor   : Symbol_Maps.Cursor;
         begin
            Self.All_Symbols.Insert
              (Canonical,
               (Symbol_Set (Item), File_Vectors.Empty_Vector),
               Cursor,
               Inserted);

            if Inserted then
               Self.All_Symbols (Cursor).Files.Reserve_Capacity (4);
            end if;

            Self.All_Symbols (Cursor).Files.Append (File);
         end;
      end loop;
   end Index_File;

   -------------
   -- Iterate --
   -------------

   function Iterate
     (Self : Indexed_File_Set'Class)
      return File_Sets.Set_Iterator_Interfaces.Reversible_Iterator'Class is
   begin
      return Self.Files.Iterate;
   end Iterate;

   ------------
   -- Length --
   ------------

   function Length (Self : Indexed_File_Set'Class) return Natural is
   begin
      return Natural (Self.Files.Length);
   end Length;

end LSP.Ada_File_Sets;
