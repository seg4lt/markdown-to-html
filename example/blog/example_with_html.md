```@@frontmatter
{
  "title": "Test page for html content",
  "description": "A blog post with html content.",
  "date": "2025-11-16"
}
```

## some js code

```jsx
const onUpdateRoomList = (frame) => {
  setRoomList(JSON.parse(frame.body))
}

const onWebSocketConnect = (_stompClient) => {
  setStompClient(_stompClient)
  _stompClient.subscribe(baseDestinationUrl, onUpdateRoomList)
}

useEffect(() => {
    const _stompClient = Stomp.over(SockJS(wsConnectUrl));
    _stompClient.connect({}, () => onWebSocketConnect(_stompClient))
}, []);
```

## jsx code

```jsx
<div className={styles.roomList}>
  {
    roomList.length > 0
      ? roomList.map(room => (
          <a className={styles.room} onClick={() => onClickJoinRoom(room)}>
            Join {room}
          </a>
        )
      )
      : ("No Chat Rooms")
  }
</div>
```

## more jsx

```jsx
<input type="text"
    value={createRoomName}
    onChange={({target: {value}}) => setCreateRoomName(value)}/>
<button onClick={onClickCreateRoom}>Create Room</button>

const onClickCreateRoom = () => {
  stompClient.send(`${baseDestinationUrl}/createRoom`, createRoomName)
}
```

## html with jx

```jsx
<h3>Messages for Room: {joinRoomName}</h3>
<pre>{JSON.stringify(messages, null, ' ')}</pre>
<div>
    <input type="text"
           value={newMessage}
           onChange={({target: {value}}) => setNewMessage(value)}
           onKeyDown={onKeyDownUserMessage}/>
</div>
```


## html code

## ul

```html
<ul>
  <li>First item</li>
  <li>Second item</li>
  <li>Third item</li>
</ul>
```

## table

```html
<table>
  <tr>
    <th>Header 1</th>
    <th>Header 2</th>           
    <th>Header 3</th>
  </tr>
    <tr>
        <td>Row 1 Col 1</td>
        <td>Row 1 Col 2</td>           
        <td>Row 1 Col 3</td>
    </tr>
    <tr>
        <td>Row 2 Col 1</td>
        <td>Row 2 Col 2</td>
        <td>Row 2 Col 3</td>
    </tr>
</table>
```