VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "CStrings2"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False

'License:   GPL
'Copyright: 2005 iDefense a Verisign Company
'Site:      http://labs.idefense.com
'
'Author:    David Zimmer <david@idefense.com, dzzie@yahoo.com>
'
'         This program is free software; you can redistribute it and/or modify it
'         under the terms of the GNU General Public License as published by the Free
'         Software Foundation; either version 2 of the License, or (at your option)
'         any later version.
'
'         This program is distributed in the hope that it will be useful, but WITHOUT
'         ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
'         FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
'         more details.
'
'         You should have received a copy of the GNU General Public License along with
'         this program; if not, write to the Free Software Foundation, Inc., 59 Temple
'         Place, Suite 330, Boston, MA 02111-1307 USA

'modified to work with console class and global progress callback

Dim d As New RegExp
Dim mc As MatchCollection
Dim m As Match

Dim filtered() As String
Public FilterResults As Boolean
Private OffsetsOnly As Boolean
Private fOut As Long
Private resultFile As String
'Private fso As New CFileSystem2

Public Function FilteredCount() As Long
    On Error Resume Next
    FilteredCount = UBound(filtered)
    If FilteredCount < 0 Then FilteredCount = 0
End Function

Public Function GetFiltered() As String
    GetFiltered = Join(filtered, vbCrLf)
End Function

''searchs for the string specified, returns csv list of offsets found at
'Function SearchOffsetsToCSV(fPath As String, ByVal find As String) As String
'    On Error GoTo hell
'
'    Dim f As Long, pointer As Long
'    Dim buf()  As Byte
'    Dim x As Long
'    Dim unicode_string As String
'
'
'    fOut = FreeFile
'    resultFile = fso.GetFreeFileName(Environ("temp"))
'    Open resultFile For Output As fOut
'
'    OffsetsOnly = True
'    f = FreeFile
'    Erase filtered
'
'    If Not fso.FileExists(fPath) Then GoTo hell
'
'    d.Pattern = find
'    d.Global = True
'    d.IgnoreCase = True
'
'    ReDim buf(9000)
'    Open fPath For Binary Access Read As f
'
'    Do While pointer < LOF(f)
'        pointer = Seek(f)
'        x = LOF(f) - pointer
'        If x < 1 Then Exit Do
'        If x < 9000 Then ReDim buf(x)
'        Get f, , buf()
'        Search buf, pointer
'    Loop
'
'    unicode_string = StrConv(find, vbUnicode, LANG_US)
'    d.Pattern = unicode_string
'
'    ReDim buf(9000)
'    pointer = 1
'    Seek f, 1
'
'    Do While pointer < LOF(f)
'        pointer = Seek(f)
'        x = LOF(f) - pointer
'        If x < 1 Then Exit Do
'        If x < 9000 Then ReDim buf(x)
'        Get f, , buf()
'        Search buf, pointer
'    Loop
'
'hell:
'    On Error Resume Next
'    Close f
'    Close fOut
'    SearchOffsetsToCSV = resultFile
'
'End Function

Private Function pl(x As String)
    Print #fOut, x
End Function

Function ExtractStrings(fPath As String, resultFile As String) As Boolean
    On Error GoTo hell
    
    Dim f As Long, pointer As Long
    Dim buf()  As Byte
    Dim x As Long
    
    OffsetsOnly = False
    Erase filtered
 
    fOut = FreeFile
    Open resultFile For Output As fOut
    
    f = FreeFile
    
    If Not fso.FileExists(fPath) Then
        MsgBox "File not found: " & fPath, vbExclamation
        GoTo done
    End If
    
    Const minStrLen = 4
    
    d.Pattern = "[\w0-9 /?.\-_=+$\\@!*\(\)#%~`\^&\|\{\}\[\]:;'""<>\,]{" & minStrLen & ",}"
    d.Global = True
    
    Print #fOut, "File: " & fso.FileNameFromPath(fPath)
    Print #fOut, "MD5:  " & LCase(hash.HashFile(fPath))
    Print #fOut, "Size: " & FileLen(fPath) & vbCrLf
    Print #fOut, "Ascii Strings:" & vbCrLf & String(75, "-")
    
    
    Open fPath For Binary Access Read As f
    blocks = (LOF(f) / 9000) + 1 'global
    
    con.WriteLine "Blocks to scan: " & blocks
    con.WriteLine "Asc [", False
    
    ReDim buf(9000)
    
    Do While pointer < LOF(f)
        pointer = Seek(f)
        x = LOF(f) - pointer
        If x < 1 Then Exit Do
        If x < 9000 Then ReDim buf(x)
        Get f, , buf()
        Search buf
        DoEvents
        block = block + 1 'global
        progressCallBack
    Loop
    
    Print #fOut, ""
    Print #fOut, "Unicode Strings:" & vbCrLf & String(75, "-")
    
    d.Pattern = "([\w0-9 /?.\-=+$\\@!\*\(\)#%~`\^&\|\{\}\[\]:;'""<>\,][\x00]){" & minStrLen & ",}"
    
    con.WriteLine "]" & vbCrLf & "Uni [", False
    curPBVal = 0
    block = 0
    ReDim buf(9000)
    pointer = 1
    Seek f, 1
    
    Do While pointer < LOF(f)
        pointer = Seek(f)
        x = LOF(f) - pointer
        If x < 1 Then Exit Do
        If x < 9000 Then ReDim buf(x)
        Get f, , buf()
        Search buf
        block = block + 1 'global
        progressCallBack
        DoEvents
    Loop
    
    con.WriteLine "]"
    Close f
    Close fOut
    ExtractStrings = True
 
Exit Function
hell:
      con.WriteLine "Error getting strings: " & Err.Description
      On Error Resume Next
      Close f
      Close fOut
done:

End Function


Private Sub Search(buf() As Byte, Optional Base As Long)
    Dim b As String
    
    b = StrConv(buf, vbUnicode)
    Set mc = d.Execute(b)
    
    For Each m In mc
    
        If OffsetsOnly Then
            pl m.FirstIndex + Base
            hits = hits + 1
        Else
            If FilterResults Then
                If Not Filter(m.value) Then
                    pl Replace(m.value, Chr(0), Empty)
                    hits = hits + 1
                End If
            Else
                pl Replace(m.value, Chr(0), Empty)
                hits = hits + 1
            End If
        End If
        
    Next
    
End Sub


'Function LineGrep(sbuf() As String, sMatch As String) As String
'
'    Dim ret() As String
'    Dim i As Long
'
'    'how i really really hate regexp...
'    'd.Pattern = "\n(\w)*" & Trim(sMatch) & "(\w)*\n"
'    'd.Global = True
'    'd.IgnoreCase = True
'    'Set mc = d.Execute(sBuf)
'    '
'    'For Each m In mc
'    '    push ret(), Mid(m.value, 2)
'    'Next
'
'    For i = 0 To UBound(sbuf)
'        If InStr(1, sbuf(i), sMatch, vbTextCompare) > 0 Then
'            push ret, sbuf(i)
'        End If
'    Next
'
'
'    LineGrep = Join(ret, vbCrLf)
'
'End Function

Private Function Filter(x As String) As Boolean
    
    
    On Error Resume Next
    Dim f As String
    
    If InStr(x, "http://") > 0 Then
        Filter = False
    ElseIf toManySpecialChars(x) Then
        If IsIde() Then f = vbTab & vbTab & "(SpecialCharsFilter)"
        push filtered, x & f
        Filter = True
    ElseIf toManyRepeats(x) Then
        If IsIde() Then f = vbTab & vbTab & "(RepeatFilter)"
        push filtered, x & f
        Filter = True
    ElseIf toManyNumbers(x) Then
        If IsIde() Then f = vbTab & vbTab & "(NumberFilter)"
        push filtered, x & f
        Filter = True
    Else
        Filter = False
    End If
 
End Function

Private Function toManyRepeats(ByVal s As String) As Boolean

    Dim os As String
    Dim hits As Long
    Dim pcent
    
    os = s 'for debugging sake
    
    If Len(s) > 20 Then
        toManyRepeats = False
        Exit Function
    End If
    
    Dim b() As Byte
    b() = StrConv(s, vbFromUnicode, LANG_US)
    
    For i = 0 To UBound(b)
        If InStr(1, s, Chr(b(i))) > 0 Then
            s = Replace(s, Chr(b(i)), Empty)
            hits = hits + 1
        End If
        If Len(s) = 0 Then Exit For
    Next
    
    sl = UBound(b) + 1 'original length
    fl = hits
    
    pcent = fl / sl
    
    If pcent < 0.54445 Then toManyRepeats = True
        
End Function

Private Function toManySpecialChars(ByVal s) As Boolean

    'Const c = "/?.-_=+$@!*()#%~`^&|{}[]:;'""<>\,]"
    Const c = "?-_=+$@!*()#~`^&|{}[]:;'""<>,]" 'javascript fragments will trigger this...
    
    Dim sl As Long
    Dim fl As Long
    Dim hits As Long
    Dim pcent As Long
    
    Dim cc
    
    sl = Len(s)
    
    For i = 1 To Len(c)
        cc = Mid(c, i, 1)
        s = Replace(s, cc, Empty)
    Next
       
    fl = Len(s)
    pcent = 100 - ((fl / sl) * 100)
    
    If pcent <= 20 Then
        toManySpecialChars = False
    Else
        toManySpecialChars = True
    End If
    
End Function

Private Function toManyNumbers(ByVal s) As Boolean
    
    Dim sl As Long
    Dim fl As Long
    Dim hits As Long
    Dim pcent As Long
    
    Dim cc
    
    sl = Len(s)
    
    For i = 1 To 9
        s = Replace(s, CStr(i), Empty)
    Next
       
    fl = Len(s)
    pcent = 100 - ((fl / sl) * 100)
    
    If pcent <= 20 Then
        toManyNumbers = False
    Else
        toManyNumbers = True
    End If
    
End Function

Private Sub Class_Initialize()
   ' FilterResults = True
End Sub
