let str = React.string

module DeleteSubmissionQuery = %graphql(
  `
  mutation UndoSubmissionMutation($targetId: ID!) {
    undoSubmission(targetId: $targetId) {
      success
    }
  }
  `
)

type status =
  | Pending
  | Undoing
  | Errored

let handleClick = (targetId, setStatus, undoSubmissionCB, event) => {
  event |> ReactEvent.Mouse.preventDefault

  if {
    open Webapi.Dom
    window |> Window.confirm("Tem certeza de que deseja excluir este envio?")
  } {
    setStatus(_ => Undoing)

    DeleteSubmissionQuery.make(~targetId, ())
    |> GraphqlQuery.sendQuery
    |> Js.Promise.then_(response => {
      if response["undoSubmission"]["success"] {
        undoSubmissionCB()
      } else {
        Notification.notice(
          "Não foi possível desfazer",
          "Atualize a página e verifique o status do envio antes de tentar novamente.",
        )
        setStatus(_ => Errored)
      }
      Js.Promise.resolve()
    })
    |> Js.Promise.catch(_ => {
      Notification.error(
        "Erro inesperado",
        "Ocorreu um erro inesperado e sua equipe foi notificada sobre isso. Atualize a página antes de tentar novamente.",
      )
      setStatus(_ => Errored)
      Js.Promise.resolve()
    })
    |> ignore
  } else {
    ()
  }
}

let buttonContents = status =>
  switch status {
  | Undoing => <span> <FaIcon classes="fas fa-spinner fa-spin mr-2" /> {"Desfazendo..." |> str} </span>
  | Pending =>
    <span>
      <FaIcon classes="fas fa-undo mr-2" />
      <span className="hidden md:inline"> {"Desfazer envio" |> str} </span>
      <span className="md:hidden"> {"Desfazer" |> str} </span>
    </span>
  | Errored =>
    <span> <FaIcon classes="fas fa-exclamation-triangle mr-2" /> {"Erro!" |> str} </span>
  }

let isDisabled = status =>
  switch status {
  | Undoing
  | Errored => true
  | Pending => false
  }

let buttonClasses = status => {
  let classes = "btn btn-small btn-danger cursor-"

  classes ++
  switch status {
  | Undoing => "wait"
  | Errored => "not-allowed"
  | Pending => "pointer"
  }
}

@react.component
let make = (~undoSubmissionCB, ~targetId) => {
  let (status, setStatus) = React.useState(() => Pending)
  <button
    title="Apagar este envio"
    disabled={status |> isDisabled}
    className={buttonClasses(status)}
    onClick={handleClick(targetId, setStatus, undoSubmissionCB)}>
    {buttonContents(status)}
  </button>
}
